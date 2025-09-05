# GitHub Actions Library

A library of reusable GitHub Actions workflows for common development tasks across Validated Patterns repositories.

## Available Workflows

### Super-Linter

Runs [GitHub Super-Linter](https://github.com/super-linter/super-linter) to validate code quality and formatting across multiple languages.

**Location:** [`.github/workflows/superlinter.yml`](.github/workflows/superlinter.yml)

#### Usage

**Basic usage:**

```yaml
name: Lint Code Base
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    uses: validatedpatterns/github-actions-library/.github/workflows/superlinter.yml@v1
```

**With custom configuration:**

```yaml
name: Lint Code Base
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    uses: validatedpatterns/github-actions-library/.github/workflows/superlinter.yml@v1
    with:
      runner: ubuntu-22.04
      sl_env: |
        VALIDATE_ALL_CODEBASE=false
        VALIDATE_MARKDOWN=false
    secrets:
      token: ${{ secrets.GITHUB_TOKEN }}
```

#### Inputs

| Input    | Description                                                   | Required | Default         |
| -------- | ------------------------------------------------------------- | -------- | --------------- |
| `runner` | GitHub runner to use                                          | No       | `ubuntu-latest` |
| `sl_env` | Extra Super-Linter environment variables (lines of KEY=VALUE) | No       | `""`            |

#### Secrets

| Secret  | Description                 | Required                          |
| ------- | --------------------------- | --------------------------------- |
| `token` | GitHub token for API access | No (falls back to `github.token`) |

#### Configuration

The workflow supports all Super-Linter configuration options through the `sl_env` input. Each line should be in `KEY=VALUE` format. For a complete list of available options, see the [Super-Linter documentation](https://thedocumentation.org/super-linter/usage/configuration/).

#### Permissions

The workflow requires the following permissions:

- `contents: read` - To checkout the repository

These permissions are automatically set by the workflow and don't need to be configured in the calling workflow.

## Versioning

- Use `@v1` for the latest stable version
- Use `@main` for the latest development version (not recommended for production)
- Specific version tags are available for pinning to exact versions

## Contributing

When adding new workflows:

1. Add the workflow YAML file to `.github/workflows/`
2. Update this README with full documentation including usage, inputs, and examples
