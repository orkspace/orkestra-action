# Examples

- `single-operator.yml` — validate, simulate, and e2e for a single operator (auto-detect all files)
- `matrix.yml` — validate, simulate, and e2e across multiple operators in a matrix job
- `discovery.yml` — simulate and e2e across every example in the repo using `./...` discovery
- `typed-operator.yml` — Go hooks / constructor operators: validate, simulate, generate, build, deploy, e2e
- `registry-publish.yml` — validate, simulate, then publish a pattern to an OCI registry on tag push

Copy any file into `.github/workflows/` and adjust paths or matrix entries to match your repo layout.
