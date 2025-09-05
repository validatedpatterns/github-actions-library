# GitHub Actions Library

A library of reusable GitHub Actions workflows for common development tasks across Validated Patterns repositories.

## Available Workflows

### Super-Linter

Runs [GitHub Super-Linter](https://github.com/super-linter/super-linter) to validate code quality and formatting across multiple languages.

**Location:** [`.github/workflows/superlinter/superlinter.yml`](.github/workflows/superlinter/superlinter.yml)

**Quick Start:**

```yaml
name: Lint Code Base
on:
  pull_request:
    branches: [main]

jobs:
  lint:
    uses: validatedpatterns/github-actions-library/.github/workflows/superlinter/superlinter.yml@v1
```

See [Super-Linter README](.github/workflows/superlinter/README.md) for full documentation.

## Versioning

- Use `@v1` for the latest stable version
- Use `@main` for the latest development version (not recommended for production)
- Specific version tags are available for pinning to exact versions

## Contributing

When adding new workflows:

1. Create a new directory under `.github/workflows/`
2. Include the workflow YAML file
3. Add a README.md documenting usage, inputs, and examples
4. Update this main README with a brief description
