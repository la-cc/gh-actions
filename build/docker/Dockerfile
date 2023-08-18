FROM python:3.10-alpine

# https://github.com/helm/helm/releases
ARG HELM_VERSION=3.12.2

ARG DYFF_VERSION=1.5.8

ENV PATH=/usr/local/src:$PATH


# update pip
RUN pip3 install --upgrade pip

# install python build dependencies
RUN apk --no-cache add \
    gcc \
    musl-dev \
    libffi-dev \
    make \
    bash \
    openssl \
    curl \
    pcre2-tools \
    grep \
    git \
    jq \
    nano \
    apache2-utils

#install github cli
RUN apk update && \
    apk add --no-cache \
    github-cli


# install yq
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq &&\
    chmod +x /usr/local/bin/yq


# install dyff
RUN curl -L https://github.com/homeport/dyff/releases/download/"v${DYFF_VERSION}"/dyff_"${DYFF_VERSION}"_linux_amd64.tar.gz -o dyff_"v${DYFF_VERSION}"_linux_amd64.tar.gz && \
    tar xfv dyff_"v${DYFF_VERSION}"_linux_amd64.tar.gz -C /usr/local/bin && \
    rm dyff_"v${DYFF_VERSION}"_linux_amd64.tar.gz

# install helm
RUN curl -sSL "https://git.io/get_helm.sh" | bash -s -- --version "v${HELM_VERSION}" && \
    helm version

RUN chmod +x /usr/local/bin/*

WORKDIR /mnt/pwd

# setup
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["bash"]
#ENTRYPOINT ["tail", "-f", "/dev/null"]