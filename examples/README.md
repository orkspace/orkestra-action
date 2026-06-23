# Examples

- `single-operator.yml` — validate, simulate, and e2e for a single operator (auto-detect all files)
- `matrix.yml` — validate, simulate, and e2e across multiple operators in a matrix job
- `discovery.yml` — simulate and e2e across every example in the repo using `./...` discovery
- `typed-operator.yml` — Go hooks / constructor operators: generate registry, build image, validate, simulate, publish katalog on tag push
- `typed-operator-with-cache.yml` — same as above, split into two jobs (image and pattern) with binary and Docker layer caching

  Both typed publishing workflows require a `values.yaml` in the operator directory so the e2e step knows which runtime image to deploy before running tests:

  ```yaml
  runtime:
    image:
      repository: ghcr.io/myorg/database-operator
      tag: latest
  ```

- `registry-publish.yml` — validate, simulate, then publish a pattern to an OCI registry on tag push

Copy any file into `.github/workflows/` and adjust paths or matrix entries to match your repo layout.
