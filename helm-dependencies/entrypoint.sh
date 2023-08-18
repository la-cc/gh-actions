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

function readFile() {
    # Read the file
    file="${PARAM_CONFIG_PATH}" # use absolute path

    # Get the number of dependencies
    count=$(yq e '.dependencies | length' $file)

}

function initGit {
    # fixes: unsafe repository ('/github/workspace' is owned by someone else)
    git config --global --add safe.directory /github/workspace

    # mandatory configs
    git config user.email $PARAM_GIT_USER_EMAIL
    git config user.name $PARAM_GIT_USER_NAME

    # fetch existing remote branches
    git fetch --all
}

function checkHelmDependenciesAndUpdateDryRun() {

    # Iterate over the list
    for ((i = 0; i < $count; i++)); do

        # Name of the dependency like External DNS
        name=$(yq e ".dependencies[$i].name" $file)
        # Path to the Chart.yaml file
        chart_file=$(yq e ".dependencies[$i].source.file" $file)
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path=$(yq e ".dependencies[$i].source.path" $file)
        # Repository name for the Artifact API
        repo_name=$(yq e ".dependencies[$i].repository.name" $file)
        # Repository url for the Artifact API
        repo_url_path=$(yq e ".dependencies[$i].repository.path" $file)

        # Sanitize the repo name
        sanitized_name=$(echo $repo_name | cut -d'/' -f1)

        #Change directory to the chart file directory
        cd $(dirname $chart_file) || exit

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        #Get the current version with the Artifact API
        current_version=$(helm search repo $repo_name --output yaml | yq eval '.[0].version')

        # Output
        echo "####################### Begin #######################"
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Current Version: $current_version"

        # If there's a difference between the versions
        if [ "$version" != "$current_version" ]; then
            echo "There's a difference between the versions."

            # Get values from the repo
            values=$(helm show values $repo_name --version $version)
            echo "$values" >values.yaml
            current_values=$(helm show values $repo_name --version $current_version)
            echo "$current_values" >current_values.yaml

            diff_result=$(dyff between values.yaml current_values.yaml) || true
            echo "$diff_result"

            # Delete the temporary files
            rm values.yaml current_values.yaml
        else
            echo "There's no difference between the versions."
        fi

        # Return to the original directory
        cd - 1>/dev/null || exit

        echo ""
        echo "####################### End #######################"
    done

}

function checkHelmDependenciesAndUpdateGitHub() {

    # Iterate over the list
    for ((i = 0; i < $count; i++)); do
        # Name of the dependency like External DNS
        name=$(yq e ".dependencies[$i].name" $file)
        # Path to the Chart.yaml file
        chart_file=$(yq e ".dependencies[$i].source.file" $file)
        # Path to the version number in the Chart.yaml file like 6.20.0
        version_path=$(yq e ".dependencies[$i].source.path" $file)
        # Repository name for the Artifact API
        repo_name=$(yq e ".dependencies[$i].repository.name" $file)
        # Repository url for the Artifact API
        repo_url_path=$(yq e ".dependencies[$i].repository.path" $file)

        # Sanitize the repo name
        sanitized_name=$(echo $repo_name | cut -d'/' -f1)

        #Change directory to the chart file directory
        cd $(dirname $chart_file) || exit

        # Read the version from the Chart.yaml file
        version=$(yq e "$version_path" "$(basename $chart_file)")
        repo_url=$(yq e "$repo_url_path" "$(basename $chart_file)")

        # Add the repo to helm
        helm repo add $sanitized_name $repo_url || true
        helm repo update 1 &>/dev/null || true

        #Get the current version with the Artifact API
        current_version=$(helm search repo $repo_name --output yaml | yq eval '.[0].version')

        # Output
        echo "Name: $name"
        echo "Version in Chart.yaml: $version"
        echo "Current Version: $current_version"

        # If there's a difference between the versions
        if [ "$version" != "$current_version" ]; then
            if [ ! $(git branch --list update-helm-$sanitized_name-$current_version) ]; then
                echo "There's a difference between the versions."

                # Get values from the repo
                values=$(helm show values $repo_name --version $version)
                echo "$values" >values.yaml
                current_values=$(helm show values $repo_name --version $current_version)
                echo "$current_values" >current_values.yaml

                diff_result=$(dyff between values.yaml current_values.yaml) || true
                # Output differences
                echo "$diff_result" >diff_result.txt
                awk '{ printf "\t%s\n", $0 }' diff_result.txt >shift_diff_result.txt
                shift_diff_result=$(cat shift_diff_result.txt)

                # Delete the temporary files
                rm values.yaml current_values.yaml diff_result.txt shift_diff_result.txt

                # check if the branch already exists
                GIT_BRANCH_EXISTS=$(git show-ref update-helm-$sanitized_name-$current_version) || true

                # returns true if the string is not empty
                if [[ -n ${GIT_BRANCH_EXISTS} ]]; then
                    echo "[-] Pull request or branch update-helm-$sanitized_name-$current_version already exists"
                else
                    # Replace the old version with the new version in the Chart.yaml file using sed
                    sed -i.bak "s/version: $version/version: $current_version/g" "$(basename $chart_file)" && rm "$(basename $chart_file).bak"

                    # Create a new branch for this change
                    git checkout -b update-helm-$sanitized_name-$current_version
                    # Add the changes to the staging area
                    git add "$(basename $chart_file)"

                    # Create a commit with a message indicating the changes
                    git commit -m "Update $name version from $version to $current_version"
                    # Push the new branch to GitHub
                    git push origin update-helm-$sanitized_name-$current_version
                    # Create a GitHub Pull Request
                    gh pr create --title "Update $name version from $version to $current_version" --body "$shift_diff_result" --base main --head update-helm-$sanitized_name-$current_version || true
                    # Get back to the source branch
                    git checkout $PARAM_GIT_DEFAULT_BRANCH
                fi

            else
                echo "Branch already exists. Checking out to the existing branch." || true
            fi

        else
            echo "There's no difference between the versions."
        fi

        # Return to the original directory
        cd - 1>/dev/null || exit

        echo ""
    done

}

function start() {
    # Read the file
    readFile
    # Check if the dependencies are up to date
    if [ "${PARAM_DRY_RUN}" == "true" ]; then
        checkHelmDependenciesAndUpdateDryRun
    fi

    if [ "${PARAM_GITHUB_RUN}" == "true" ]; then
        initGit
        checkHelmDependenciesAndUpdateGitHub
    fi
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
