# Super-Linter Workflow

A reusable GitHub Actions workflow that runs [GitHub Super-Linter](https://github.com/super-linter/super-linter) on your repository to validate code quality and formatting across multiple languages.

## Usage

### Basic usage

```yaml
name: Lint Code Base
on:
  pull_request:
    branches: [main]

jobs:
  lint:
    uses: validatedpatterns/github-actions-library/.github/workflows/superlinter/superlinter.yml@v1
```

### With custom configuration

```yaml
name: Lint Code Base
on:
  pull_request:
    branches: [main]

jobs:
  lint:
    uses: validatedpatterns/github-actions-library/.github/workflows/superlinter/superlinter.yml@v1
    with:
      runner: ubuntu-22.04
      sl_version: slim-v7
      sl_env: |
        VALIDATE_ALL_CODEBASE=false
        VALIDATE_MARKDOWN=false
    secrets:
      token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input        | Description                                                   | Required | Default         |
| ------------ | ------------------------------------------------------------- | -------- | --------------- |
| `runner`     | GitHub runner to use                                          | No       | `ubuntu-latest` |
| `sl_version` | GitHub Super-Linter version ref                               | No       | `slim-v8`       |
| `sl_env`     | Extra Super-Linter environment variables (lines of KEY=VALUE) | No       | `""`            |

## Secrets

| Secret  | Description                 | Required                          |
| ------- | --------------------------- | --------------------------------- |
| `token` | GitHub token for API access | No (falls back to `github.token`) |

## Configuration

The workflow supports all Super-Linter configuration options through the `sl_env` input. Each line should be in `KEY=VALUE` format. For a complete list of available options, see the [Super-Linter documentation](https://thedocumentation.org/super-linter/usage/configuration/).

## Permissions

The workflow requires the following permissions:

- `contents: read` - To checkout the repository
- `pull-requests: read` - To read pull request information

These permissions are automatically set by the workflow and don't need to be configured in the calling workflow.
