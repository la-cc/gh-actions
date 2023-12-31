#!/bin/bash
set -eo pipefail

# -------- environments check  ------------ #

PARAM_CONFIG_PATH=${1:?"Missing CONFIG_PATH"}
PARAM_GIT_USER_EMAIL=${2:?"Missing GIT_USER_EMAIL"}
PARAM_GIT_USER_NAME=${3:?"Missing GIT_USER_NAME"}
PARAM_GIT_DEFAULT_BRANCH=${4:?"Missing GIT_DEFAULT_BRANCH"}
PARAM_DRY_RUN=${5:?"Missing DRY_RUN"}
PARAM_GITHUB_RUN=${6:?"Missing GITHUB_RUN"}

# -------- functions ------------ #

# Set path to the config file
file="${PARAM_CONFIG_PATH}" # use absolute path

# Load dependencies in memory
dependencies=$(yq e . $file)

function initGit {
    # fixes: unsafe repository ('/github/workspace' is owned by someone else)
    git config --global --add safe.directory /github/workspace

    # mandatory configs
    git config user.email $PARAM_GIT_USER_EMAIL
    git config user.name $PARAM_GIT_USER_NAME

    # fetch existing remote branches
    git fetch origin --prune
}

function readDependenciesFromFile() {
    # Get the number of dependencies
    count=$(echo "${dependencies}" | yq e '.dependencies | length')

}

function checkHelmDependencies() {
    for ((i = 0; i < $count; i++)); do

        dependencyPath=".dependencies[$(echo "${dependencies}" | yq e ".dependencies[$i].arrayPosition // 0")]"
        chartSourcePath=$(echo "${dependencies}" | yq e ".dependencies[$i].sourcePath")

        # Name of the dependency like External DNS
        name=$(echo "${dependencies}" | yq e ".dependencies[$i].name")
        # Lowercase name of the dependency like external-dns
        lower_name=$(echo $name | tr '[:upper:]' '[:lower:]')
        # Path to the Chart.yaml file
        chart_file=$chartSourcePath/Chart.yaml
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path="${dependencyPath}.version"
        # Repository name for the Artifact API
        repo_name=$(echo "${dependencies}" | yq e ".dependencies[$i].repositoryName")
        # Repository url for the Artifact API
        repo_url_path="${dependencyPath}.repository"

        # Sanitize the repo name
        sanitized_repo_name=$(echo $repo_name | cut -d'/' -f1)
        # Sanitize the app name
        sanitized_name=$(echo $repo_name | awk -F'/' '{print $NF}')
        #Change directory to the chart file directory
        pushd $chartSourcePath >/dev/null

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_repo_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        #Get the latest version with the Artifact API
        latest_version=$(helm search repo $repo_name --output yaml | yq e '.[0].version')

        # Output
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Latest Version in Repository: $latest_version"

        initGit
        diffBetweenVersions

        # Return to the original directory
        popd >/dev/null
    done
}

function diffBetweenVersions() {
    if [ "$version" != "$latest_version" ]; then
        echo "There is a difference between the versions."

        tplBranchName=update-helm-$sanitized_name-from-$version-to-$latest_version

        # returns true if the string is not empty
        if [[ -n $(git show-ref $tplBranchName) ]] && [[ "$PARAM_DRY_RUN" != "true" ]]; then
            echo "[-] Pull request or branch $tplBranchName already exists"
        else
            tempDir=$(mktemp -d)

            diffValuesFile="${tempDir}/diff_value.yaml"
            diffLatestValuesFile="${tempDir}/diff_latest_value.yaml"
            diffResultFile="${tempDir}/diff_result.txt"
            shiftDiffResultFile="${tempDir}/shift_diff_result.txt"

            # Get values from the repo
            helm show values $repo_name --version $version >$diffValuesFile
            helm show values $repo_name --version $latest_version >$diffLatestValuesFile

            dyff between $diffValuesFile $diffLatestValuesFile >$diffResultFile

            awk '{ printf "\t%s\n", $0 }' $diffResultFile >$shiftDiffResultFile
            shift_diff_result=$(cat $shiftDiffResultFile)

            if [ "$PARAM_DRY_RUN" == "true" ]; then
                dryRun
            elif [ "$PARAM_GITHUB_RUN" == "true" ]; then
                gitHubPR
            fi

            rm -rf $tempDir
        fi
    else
        echo "There's no difference between the versions."
    fi
}

function updateVersionInChartFile() {
    # Replace the old version with the new version in the Chart.yaml file using sed
    yq e -i "$version_path = \"$latest_version\"" "$(basename $chart_file)"
}

function createCommitAndPushBranch() {

    # Create a new branch for this change
    git checkout -b $tplBranchName

    # Add the changes to the staging area
    git add "$(basename $chart_file)"

    # Create a commit with a message indicating the changes
    git commit -m "Update $name version from $version to $latest_version"

    # Push the new branch to GitHub
    git push origin $tplBranchName

}

function gitHubPR() {
    updateVersionInChartFile
    createCommitAndPushBranch

    gh pr create \
        --title "Update $name version from $version to $latest_version" \
        --body "$shift_diff_result" \
        --base $PARAM_GIT_DEFAULT_BRANCH \
        --head $tplBranchName || true

    # Get back to the source branch
    git checkout $PARAM_GIT_DEFAULT_BRANCH

}

function dryRun() {
    cat $diffResultFile
}

function start() {

    # Read the file
    readDependenciesFromFile
    # Check if the dependencies are up to date
    checkHelmDependencies
}

echo "[+] helm-dependencies"
# global
echo "[*] GITHUB_TOKEN=${GITHUB_TOKEN}"
echo "[*] GITHUB_REPOSITORY=${GITHUB_REPOSITORY}"
echo "[*] GITHUB_SHA=${GITHUB_SHA}"
# params
echo "[*] CONFIG_PATH=${PARAM_CONFIG_PATH}"
echo "[*] GIT_USER_EMAIL=${PARAM_GIT_USER_EMAIL}"
echo "[*] GIT_USER_NAME=${PARAM_GIT_USER_NAME}"
echo "[*] GIT_DEFAULT_BRANCH=${PARAM_GIT_DEFAULT_BRANCH}"
echo "[*] DRY_RUN=${PARAM_DRY_RUN}"
echo "[*] GITHUB_RUN=${PARAM_GITHUB_RUN}"

gh --version
gh auth status

# -------- Main  ------------ #
start

echo "[-] helm-dependencies"
