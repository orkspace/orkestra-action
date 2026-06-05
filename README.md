# Orkestra GitHub Action

<div align="center">
    <img src="logo.svg" width="140" alt="Orkestra Logo">
</div>

The official GitHub Action for Orkestra — runs the full `ork` CLI surface from any workflow.

---

## How it works

1. Installs the `ork` CLI (pinned or latest)
2. Runs only the commands you enable — everything else is skipped
3. Exposes file paths as outputs for steps that produce artifacts

Steps run in this order: **validate → simulate → plan → template → generate → e2e → registry**

---

## Quick start

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: "true"
    simulate: "true"
    e2e: "true"
```

All three commands auto-detect their files (`katalog.yaml`, `simulate.yaml`, `e2e.yaml`) from `working-directory`.

---

## Inputs

### Common

| Input | Default | Description |
|-------|---------|-------------|
| `ork-version` | `latest` | Version of the `ork` CLI to install |
| `working-directory` | `.` | Directory to run all commands in |

### `validate`

| Input | Default | Description |
|-------|---------|-------------|
| `validate` | `""` | `'true'` = auto-detect. Path = validate that file. Empty = skip. |
| `validate-depth` | `single` | `full` → `ork validate --full` (RBAC, dependency graph, per-CRD permissions) |

### `simulate`

Runs `ork simulate` — no cluster required. Reads `simulate.yaml` (assert mode) or `e2e.yaml`/`katalog.yaml` (op-print mode).

> `simulate` in CI fails on cycle errors and on `expect:` assertion failures. For full value, commit a `simulate.yaml` with assertions alongside your katalog. Generate one with `ork simulate init`.

| Input | Default | Description |
|-------|---------|-------------|
| `simulate` | `""` | `'true'` = auto-detect. Path = use that file. Empty = skip. |
| `simulate-depth` | `single` | `full` → `ork simulate ./...` (discovers all simulate.yaml + e2e.yaml recursively) |
| `simulate-katalog` | `""` | Explicit `katalog.yaml` path. Always wins over `simulate` and `simulate-depth`. |
| `simulate-cr` | `""` | Explicit `cr.yaml` path. Paired with `simulate-katalog`. Falls back to `cr.yaml` in cwd if omitted. |
| `simulate-crd` | `""` | CRD name to target when the katalog defines multiple. All CRDs if omitted. |
| `simulate-cycles` | `""` | Maximum reconcile cycles (`ork simulate --cycles`). |
| `simulate-skip-external` | `true` | Stub `external:` HTTP calls — no real network. Default `true` since CI has no dev server. |
| `simulate-skip` | `""` | Comma-separated path patterns to skip in `./...` discovery. |
| `simulate-debug` | `false` | Save per-cycle op trace to `simulate-debug-output` (`ork simulate --debug-ops`). |
| `simulate-debug-output` | `simulate-debug.txt` | File to write the `--debug-ops` trace to. |

### `plan`

| Input | Default | Description |
|-------|---------|-------------|
| `plan` | `""` | Path to `katalog.yaml` to diff against the deployed Katalog. Empty = skip. |
| `plan-bundle` | `""` | Path to a `bundle.yaml` — reads the deployed Katalog from it. No cluster access needed. |
| `plan-cm` | `""` | Path to a `configmap.yaml` — reads the deployed Katalog from it. No cluster access needed. |
| `plan-namespace` | `orkestra-system` | Namespace — only used when neither `plan-bundle` nor `plan-cm` is set. |
| `plan-output` | `plan.txt` | File to write the plan diff output to. |

One of `plan-bundle` or `plan-cm` is required when `plan` is set.

### `template`

| Input | Default | Description |
|-------|---------|-------------|
| `template` | `""` | Path to `katalog.yaml` to render the fully-expanded runtime Katalog. Empty = skip. |
| `template-yaml-output` | `template.yaml` | Output file for the YAML render (`ork template --yaml`). |
| `template-json-output` | `template.json` | Output file for the JSON render (`ork template --json`). |

### `generate bundle`

| Input | Default | Description |
|-------|---------|-------------|
| `generate-bundle` | `""` | Path to `katalog.yaml`. Empty = skip. |
| `generate-bundle-output` | `bundle.yaml` | Output file path |
| `generate-bundle-namespace` | `orkestra-system` | Kubernetes namespace |

### `generate configmap`

| Input | Default | Description |
|-------|---------|-------------|
| `generate-configmap` | `""` | Path to `katalog.yaml` or `komposer.yaml`. Empty = skip. |
| `generate-configmap-output` | `configmap.yaml` | Output file path |
| `generate-configmap-namespace` | `orkestra-system` | Kubernetes namespace |

### `generate rbac`

| Input | Default | Description |
|-------|---------|-------------|
| `generate-rbac` | `""` | Path to `katalog.yaml`. Empty = skip. |
| `generate-rbac-output` | `rbac.yaml` | Output file path |
| `generate-rbac-namespace` | `orkestra-system` | Namespace for the ServiceAccount |

### `generate registry` (typed operators)

| Input | Default | Description |
|-------|---------|-------------|
| `generate-registry` | `""` | Comma-separated project directories. Writes `zz_generated_runtime_registry.go` in each. Empty = skip. |

### `e2e`

| Input | Default | Description |
|-------|---------|-------------|
| `e2e` | `""` | `'true'` = auto-detect `e2e.yaml`. Path = use that file. Empty = skip. |
| `e2e-depth` | `single` | `full` → `ork e2e ./...` (discovers all e2e.yaml files recursively) |
| `e2e-keep-cluster` | `false` | Keep the kind cluster after the test (useful for debugging) |
| `e2e-cluster` | `""` | Use an existing kubectl context instead of creating a cluster |
| `e2e-wait` | `3s` | Wait between tests in `./...` discovery mode. Lets clusters fully tear down. |
| `e2e-skip` | `""` | Comma-separated path patterns to skip in `./...` discovery. |

### `registry push`

| Input | Default | Description |
|-------|---------|-------------|
| `registry-push` | `""` | `"name:version /path/to/dir"` or `"/path/to/dir"`. Empty = skip. |
| `registry-push-force` | `false` | Push even if e2e fails or metadata version differs |
| `registry-push-no-e2e` | `false` | Skip the e2e gate (even if `e2e.yaml` is present) |
| `registry-url` | `""` | OCI registry URL. Also read from `ORK_REGISTRY` env var. |
| `registry-username` | `""` | Registry username |
| `registry-password` | `""` | Registry password or token |

### `registry pull`

| Input | Default | Description |
|-------|---------|-------------|
| `registry-pull` | `""` | `"name:version"`. Empty = skip. |
| `registry-pull-out` | `""` | Directory to extract the pulled pattern into |

---

## Outputs

| Output | Description |
|--------|-------------|
| `plan-file` | Path to the plan diff output file (default `plan.txt`) |
| `template-yaml-file` | Path to the YAML-rendered runtime Katalog |
| `template-json-file` | Path to the JSON-rendered runtime Katalog |
| `bundle-file` | Path to the generated `bundle.yaml` |
| `configmap-file` | Path to the generated `configmap.yaml` |
| `rbac-file` | Path to the generated `rbac.yaml` |
| `registry-file` | Path to the generated `zz_generated_runtime_registry.go` |
| `simulate-debug-file` | Path to the `--debug-ops` trace file (set when `simulate-debug: true`) |
| `pattern-path` | Local path where the pulled pattern was extracted |

---

## Examples

### Standard CI — validate, simulate, e2e

The CI pyramid: each layer is cheaper than the next. Simulate catches logic errors without a cluster.

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: "true"
    simulate: "true"    # reads simulate.yaml → fails on assertion errors
    e2e: "true"         # reads e2e.yaml → full cluster test
```

### Simulate with explicit katalog and CR

Use when you want to run simulate directly against a katalog without a `simulate.yaml` file.

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    simulate-katalog: ./katalog.yaml
    simulate-cr: ./cr.yaml
    simulate-cycles: "5"
```

### Discovery mode — simulate and e2e across all examples

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    simulate-depth: full
    simulate-skip: "vendor,testdata"
    e2e-depth: full
    e2e-skip: "vendor,testdata"
    e2e-wait: "5s"
```

### Matrix across multiple operators

```yaml
strategy:
  matrix:
    example:
      - examples/beginner/01-hello-website
      - examples/beginner/02-with-service
      - examples/advanced/09-hooks

steps:
  - uses: actions/checkout@v4
  - uses: orkspace/orkestra-action@v1
    with:
      working-directory: ${{ matrix.example }}
      validate: "true"
      simulate: "true"
      e2e: "true"
```

### Generate and upload a deployment bundle

```yaml
- name: Generate bundle
  uses: orkspace/orkestra-action@v1
  id: bundle
  with:
    generate-bundle: ./katalog.yaml

- name: Upload
  uses: actions/upload-artifact@v4
  with:
    name: bundle
    path: ${{ steps.bundle.outputs.bundle-file }}
```

### Typed operator — generate registry, build image, deploy, then e2e

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: "true"
    simulate: "true"
    generate-registry: "."

- run: CGO_ENABLED=0 go build -tags runtime -o ./bin/operator ./cmd/operator

- uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ghcr.io/myorg/my-operator:${{ github.sha }}

- run: |
    helm upgrade --install orkestra orkestra/orkestra \
      --set runtime.image.repository=ghcr.io/myorg/my-operator \
      --set runtime.image.tag=${{ github.sha }} \
      --namespace orkestra-system --create-namespace --wait

- uses: orkspace/orkestra-action@v1
  with:
    e2e: "true"
    e2e-cluster: kind-ork-e2e
```

See [`examples/typed-operator.yml`](examples/typed-operator.yml) for the full workflow.

### Publish a pattern on tag push

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: "true"
    simulate: "true"
    registry-push: "my-operator:${{ github.ref_name }} ."
    registry-url: "ghcr.io/${{ github.repository_owner }}/patterns"
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

---

## License

[Apache 2.0](./LICENSE)
