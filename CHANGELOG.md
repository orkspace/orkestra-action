### Changelog

# Changelog

## Unreleased

### Added
- Initial reusable composite GitHub Action `action.yml` that installs the `ork` CLI and runs `ork e2e`
- examples/single-operator.yml demonstrating a single-operator E2E job
- Updated README.md to document the thin wrapper action and `e2e.yaml` driven workflow

### Changed
- Examples updated to use the new wrapper action and `e2e.yaml` as the single source of truth for E2E tests
- examples/matrix.yml updated to run per-example E2E specs via the wrapper action
- Action documentation simplified to reflect the minimal inputs and behavior of the composite action

### Fixed
- No fixes in this release

### Removed
- Dockerfile
- entrypoint.sh
- examples/generate-bundle.yml
- examples/init.yml
- examples/multi-environment-gitops.yml
- examples/publish-pattern-2.yml
- examples/publish-pattern.yml
- examples/template.yml
- examples/validate.yml

