# Orkestra CI Action

<div align="center">
    <img src="logo.svg" width="140" alt="Orkestra CI Action Logo">
    <br>
    <img src="https://img.shields.io/badge/Orkestra-CI%20Action-4B32C3?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Orkestra CI Badge">
</div>

A lightweight, deterministic GitHub Action for running versioned Orkestra CLI commands in CI.

Use it to:

- Validate Katalogs  
- Template Katalogs  
- Generate RBAC  
- Generate ConfigMaps  
- Generate Bundles  
- Run `ork init` for example packs  
- Produce outputs for downstream steps  
- Build GitOps pipelines  
- Power E2E tests  
- Publish Operator Patterns

Every step is optional.  
Every output is consumable.  
Every run is reproducible.

---

## Features

- Versioned Ork CLI (`ork-version` input)  
- Auto-detects `katalog.yaml` or `komposer.yaml`  
- Composable: run one step or many  
- Deterministic: same inputs → same outputs  
- CI-friendly: no cluster access required  
- GitOps-friendly: bundle, RBAC, configmap  
- E2E-friendly: supports `ork init`  

---

## Usage

You can run the action in multiple small steps, or combine them.

All boolean inputs default to false.

---

## Validate

```yaml
- uses: orkestra/ci-action@v1
  id: validate
  with:
    validate: true

- name: Print validation log
  run: cat ${{ steps.validate.outputs.validate_log }}
```

---

## Template

```yaml
- uses: orkestra/ci-action@v1
  id: template
  with:
    template: true

- name: List rendered files
  run: ls -R ${{ steps.template.outputs.template_dir }}
```

---

## Generate RBAC

```yaml
- uses: orkestra/ci-action@v1
  id: rbac
  with:
    generate-rbac: true

- name: Show RBAC
  run: cat ${{ steps.rbac.outputs.rbac_file }}
```

---

## Generate ConfigMap

```yaml
- uses: orkestra/ci-action@v1
  id: cfg
  with:
    generate-configmap: true
```

---

## Generate Bundle

```yaml
- uses: orkestra/ci-action@v1
  id: bundle
  with:
    generate-bundle: true

- name: Apply bundle
  run: kubectl apply -f ${{ steps.bundle.outputs.bundle_file }}
```

---

## Publish Pattern

```yaml
- uses: orkestra/ci-action@v1
  id: publish
  with:
    registry-command: push
    registry-ref: myorg/website:1.0.0
    pattern-dir: test/my-operator       # Defaults to current working directory
    registry-username: ${{ secrets.REGISTRY_USER }}
    registry-password: ${{ secrets.REGISTRY_TOKEN }}
```

Pushes the current directory (must contain `katalog.yaml` and `crd.yaml`) as an OCI pattern to the default registry (`ghcr.io`). Override `registry-server` if needed.

---

## Init Example Pack

```yaml
- uses: orkestra/ci-action@v1
  id: init
  with:
    init: true
    pack: beginner
    example-subdir: 01-hello-website

- name: Inspect example pack
  run: ls -R ${{ steps.init.outputs.example_dir }}
```

---

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `katalog` | "" | Path to existing `katalog.yaml` or `komposer.yaml` (ignored if `init=true`) |
| `init` | false | Initialize a new operator using the specified pack and example-subdir |
| `pack` | beginner | Pack to use when `init=true` (`beginner`, `intermediate`, `advanced`, `use-cases`) |
| `example-subdir` | "" | Subdirectory under `examples/<pack>` containing the katalog, CRD, and CR (required if `init=true`) |
| `ork-version` | latest | Version of Ork CLI to install |
| `output-dir` | orkestra-artifacts | Directory to write generated artifacts into |
| `kompose` | false | Run `ork kompose` before other steps |
| `validate` | false | Run `ork validate` |
| `template` | false | Run `ork template` |
| `generate-rbac` | false | Run `ork generate rbac` |
| `generate-configmap` | false | Run `ork generate configmap` |
| `namespace` | orkestra-system | Kubernetes namespace for generated resources |
| `generate-bundle` | false | Run `ork generate bundle` |
| `generate-registry` | false | Run `ork generate registry` for typed operators |
| `registry-server` | ghcr.io | OCI registry server |
| `registry-username` | "" | Username for registry login |
| `registry-password` | "" | Password or token for registry login |
| `registry-command` | "" | Registry command to run (`push`, `pull`, `info`, `list`) |
| `registry-ref` | "" | Pattern reference (e.g., `website:1.0.0`) |
| `pattern-dir` | "" | Directory to push when using `registry-command=push` |

---

## Outputs

These outputs can be consumed by later steps:

| Output | Description |
|--------|-------------|
| `komposed_katalog` | Path to the komposed `katalog.yaml` |
| `validate_log` | Path to validation log |
| `template_dir` | Directory containing rendered templates |
| `rbac_file` | Generated RBAC YAML file |
| `configmap_file` | Generated ConfigMap YAML file |
| `bundle_file` | Generated bundle YAML file |
| `init_dir` | Root directory of the initialized operator (only if `init=true`) |
| `operator_dir` | Directory containing the expanded example pack (`examples/<pack>`) |
| `katalog_path` | Path to the `katalog.yaml` file (after init/kompose) |
| `crd_path` | Path to the CRD YAML file (only if `init=true`) |
| `cr_path` | Path to the CR YAML file (only if `init=true`) |
| `example_dir` | Directory containing the chosen example |
| `namespace` | Kubernetes namespace used for generated resources (default: `orkestra-system`) |
| `registry_file` | Path to the generated registry file (`pkg/runtime/zz_generated_runtime_registry.go`) |
| `pattern_path` | Local filesystem path to the pulled pattern (for `pull` command) |

---

# Auto-detection logic

If `katalog` is not provided:

1. Use `katalog.yaml` if present  
2. Else use `komposer.yaml`  
3. Else fail with a clear error  

This keeps the action simple and predictable.

---

## Example: Full E2E Pipeline

```yaml
name: E2E

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup operator, validate katalog and generate bundle
        id: ork
        uses: orkspace/orkestra-action@v0.0.1
        with:
          init: true
          pack: beginner
          example-subdir: 01-hello-website
          validate: true
          generate-bundle: true

      - name: Create kind cluster
        uses: helm/kind-action@v1

      - name: Apply Orkestra bundle
        run: kubectl apply -f ${{ steps.bundle.outputs.bundle_file }}

      - name: Install Orkestra Helm chart
        run: helm install orkestra charts/orkestra
```

---

## License
[Apache 2.0.](./LICENSE)

---

