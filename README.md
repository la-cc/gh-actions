# WIP!!

**_NOTE:_** this project was inspired by [hckops](https://github.com/hckops/actions)!

To test it, fork this repo. I recommend you to fork the main branch only.

## Default - The GitHub Way

**_NOTE:_** you need to change the workflow permissions from `Read repository contents and package permissions` to `Read and write permissions` under your repository (Settings -> Actions -> General -> Workflow permissions).

You can keep the config like:

```
name: test-helm-dependencies

on:
  # enable manual trigger
  workflow_dispatch:
  # https://cron.help
  schedule:
    # every 12 hours
    - cron: "0 0,12 * * *"
  push:
    branches:
      - main
    paths:
      - ".github/workflows/test-helm-dependencies.yml"
      - "helm-dependencies/**"
      - "examples/dependencies.yaml"

jobs:
  test-helm-dependencies:
    name: Test Example Chart
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Helm Dependencies
        uses: ./helm-dependencies
        with:
          config-path: examples/dependencies.yaml
          user-email: "dep-sheriff-bot@users.noreply.github.com"
          user-name: "dep-sheriff-bot"
          default-branch: "main"
          dry-run: false
          github-run: true
        env:
          # mandatory: not declared explicitly, but used by gh-cli
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # not required: declared only for documentation because they are automatically added at runtime
          GITHUB_REPOSITORY: ${{ env.GITHUB_REPOSITORY }}
          GITHUB_SHA: ${{ env.GITHUB_SHA }}
```

The Action will be triggered on push to main or every 12 hours as cronjob.

You will get an output like:

![Update Version](images/github-1.png)
![Pull Request Text](images/github-0.png)

## Info - The Dry-Run Way

You need only to set the `github-run` flag to `false` and the `dry-run` flag to `true` like:

```
name: test-helm-dependencies

on:
  # enable manual trigger
  workflow_dispatch:
  # https://cron.help
  schedule:
    # every 12 hours
    - cron: "0 0,12 * * *"
  push:
    branches:
      - main
    paths:
      - ".github/workflows/test-helm-dependencies.yml"
      - "helm-dependencies/**"
      - "examples/dependencies.yaml"

jobs:
  test-helm-dependencies:
    name: Test Example Chart
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Helm Dependencies
        uses: ./helm-dependencies
        with:
          config-path: examples/dependencies.yaml
          user-email: "dep-sheriff-bot@users.noreply.github.com"
          user-name: "dep-sheriff-bot"
          default-branch: "main"
          dry-run: true
          github-run: false
        env:
          # mandatory: not declared explicitly, but used by gh-cli
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # not required: declared only for documentation because they are automatically added at runtime
          GITHUB_REPOSITORY: ${{ env.GITHUB_REPOSITORY }}
          GITHUB_SHA: ${{ env.GITHUB_SHA }}
```

The Action will be triggered on push to main or every 12 hours as cronjob.

You will get an output like:

![Pull Request Text](images/dry-run-0.png)

## Use this action from GitHub Marketplace - TBD