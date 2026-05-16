# Orkestra GitHub Action

<div align="center">
    <img src="logo.svg" width="140" alt="Orkestra Logo">
</div>

A GitHub Action that installs the `ork` CLI and exposes every `ork` command as a composable step — validate, plan, generate, e2e, registry push/pull.

---

## How it works

1. Installs the `ork` CLI (pinned or latest)
2. Runs only the commands you enable via inputs — everything else is skipped
3. Exposes file paths as outputs for steps that produce artifacts

Each command is an independent conditional step. You can run one per job step or combine several in one action call.

---

## Quick start

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: ./katalog.yaml
    e2e: ./e2e.yaml
```

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
| `validate` | `""` | Path to a Katalog, Komposer, Motif, or E2E file. Empty = skip. |

### `plan`

| Input | Default | Description |
|-------|---------|-------------|
| `plan` | `""` | Path to `katalog.yaml` to diff. Empty = skip. |
| `plan-bundle` | `""` | Path to a `bundle.yaml` — reads the deployed Katalog from it. No cluster access needed. |
| `plan-cm` | `""` | Path to a `configmap.yaml` — reads the deployed Katalog from it. No cluster access needed. |
| `plan-namespace` | `orkestra-system` | Namespace — only used when neither `plan-bundle` nor `plan-cm` is set. |
| `plan-output` | `plan.txt` | File to write the plan diff output to. |

One of `plan-bundle` or `plan-cm` is required when `plan` is set.

### `template`

| Input | Default | Description |
|-------|---------|-------------|
| `template` | `""` | Path to `katalog.yaml` to render the fully-expanded runtime Katalog from. Empty = skip. |
| `template-yaml-output` | `template.yaml` | Output file for the YAML render (`ork template --yaml`). |
| `template-json-output` | `template.json` | Output file for the JSON render (`ork template --json`). |

### `generate bundle`

| Input | Default | Description |
|-------|---------|-------------|
| `generate-bundle` | `""` | Path to `katalog.yaml` to generate a bundle from. Empty = skip. |
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
| `generate-rbac-namespace` | `orkestra-system` | Kubernetes namespace for the ServiceAccount |

### `generate registry` (typed operators)

| Input | Default | Description |
|-------|---------|-------------|
| `generate-registry` | `""` | Comma-separated list of project directories. Generates `zz_generated_runtime_registry.go` in each. Empty = skip. |

### `e2e`

| Input | Default | Description |
|-------|---------|-------------|
| `e2e` | `""` | Path to the `e2e.yaml` spec file. Empty = skip. |
| `e2e-keep-cluster` | `false` | Keep the kind cluster after the test |
| `e2e-cluster` | `""` | Use an existing kubectl context instead of creating a cluster |

### `registry push`

| Input | Default | Description |
|-------|---------|-------------|
| `registry-push` | `""` | `"name:version /path/to/dir"` or `"/path/to/dir"`. Empty = skip. |
| `registry-push-force` | `false` | Push even if e2e fails or metadata version differs |
| `registry-push-no-e2e` | `false` | Skip the e2e gate (even if `e2e.yaml` is present in the pattern dir) |
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
| `template-yaml-file` | Path to the YAML-rendered runtime Katalog (default `template.yaml`) |
| `template-json-file` | Path to the JSON-rendered runtime Katalog (default `template.json`) |
| `bundle-file` | Path to the generated `bundle.yaml` |
| `configmap-file` | Path to the generated `configmap.yaml` |
| `rbac-file` | Path to the generated `rbac.yaml` |
| `registry-file` | Path to the generated `zz_generated_runtime_registry.go` |
| `pattern-path` | Local path where the pulled pattern was extracted |

---

## Examples

### Validate and run e2e

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: ./katalog.yaml
    e2e: ./e2e.yaml
```

### Generate and upload a deployment bundle

```yaml
- name: Generate bundle
  uses: orkspace/orkestra-action@v1
  id: bundle
  with:
    generate-bundle: ./katalog.yaml
    generate-bundle-output: bundle.yaml

- name: Upload
  uses: actions/upload-artifact@v4
  with:
    name: bundle
    path: ${{ steps.bundle.outputs.bundle-file }}
```

### Typed operator — generate registry, build image, deploy, then e2e

Typed operators (Go hooks / constructors) require a custom binary and Docker image.
`generate-registry` writes the Go glue code. You then build the image and deploy
Orkestra with `--set runtime.image.repository=... --set runtime.image.tag=...`.

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    validate: ./katalog.yaml
    generate-registry: "."              # writes zz_generated_runtime_registry.go

- run: go build -o ./bin/operator ./cmd/operator

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
    e2e: ./e2e.yaml
    e2e-cluster: kind-ork-e2e
```

See [`examples/typed-operator.yml`](examples/typed-operator.yml) for the complete workflow including kind cluster setup and image loading.

### Publish a pattern on tag push

```yaml
- uses: orkspace/orkestra-action@v1
  with:
    registry-push: "my-operator:${{ github.ref_name }} ."
    registry-url: "ghcr.io/${{ github.repository_owner }}/patterns"
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### Matrix across multiple operators

```yaml
strategy:
  matrix:
    example:
      - examples/beginner/01-hello-website
      - examples/advanced/09-hooks

steps:
  - uses: actions/checkout@v4
  - uses: orkspace/orkestra-action@v1
    with:
      working-directory: ${{ matrix.example }}
      validate: ./katalog.yaml
      e2e: ./e2e.yaml
```

---

## License

[Apache 2.0](./LICENSE)
