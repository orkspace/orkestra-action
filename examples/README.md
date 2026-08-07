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
- `gate-pr.yml` — run `ork gate` on every PR that touches `cr.yaml` or `katalog.yaml` — no cluster needed
- `serve-deploy-oidc.yml` — deploy a CR via the Gateway API on push to main, authenticating with a GitHub Actions OIDC token (no stored secret)
- `serve-full-pipeline.yml` — full pipeline: validate + simulate + gate + serve-play on PR, then dry-run + deploy with OIDC on merge

Copy any file into `.github/workflows/` and adjust paths or matrix entries to match your repo layout.
