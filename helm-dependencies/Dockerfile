FROM ghcr.io/la-cc/helm-dependencies-update-helper:0.0.7

# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
ENV GITHUB_TOKEN=${GITHUB_TOKEN}
ENV GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
ENV GITHUB_SHA=${GITHUB_SHA}

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
