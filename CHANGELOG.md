# Changelog

## v0.1.1

### Added
- `comment-on-pr` input on the main action — set to `"true"` to post the `ork plan` diff as a PR comment in the same job. No extra step required; the comment is posted at the end of the action run. Requires `pull-requests: write` on the job.
- `github-token` input — token used for posting the PR comment. Defaults to `${{ github.token }}`.
- `plan-no-changes` output — `"true"` when `ork plan` detects no diff between the katalog and the deployed state. Useful for conditional steps and cross-job comment logic.
- `comment-plan-on-pr/action.yml` — standalone composite action for the cross-job pattern: plan in one job, comment in another. Accepts `plan-artifact` (downloads from GitHub Actions artifact store) or `plan-file` (reads directly). Handles all plan states: no changes, success with diff, failure, cancelled, and skipped.
- `examples/plan-pr.yml` — two side-by-side patterns: opt-in (single job) and cross-job (plan job + comment job with separate permissions).

---



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

