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

## Init Example Pack

```yaml
- uses: orkestra/ci-action@v1
  id: init
  with:
    init: true
    example-subdir: beginner

- name: Inspect example pack
  run: ls -R ${{ steps.init.outputs.example_dir }}
```

---

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `katalog` | auto-detect | Path to katalog.yaml or komposer.yaml |
| `ork-version` | latest | Version of Ork CLI to install |
| `output-dir` | orkestra-artifacts | Directory for generated files |
| `validate` | false | Run `ork validate` |
| `template` | false | Run `ork template` |
| `generate-rbac` | false | Run `ork generate rbac` |
| `generate-configmap` | false | Run `ork generate configmap` |
| `generate-bundle` | false | Run `ork generate bundle` |
| `init` | "" | Run `ork init <args>` |

---

## Outputs

These outputs can be consumed by later steps:

| Output | Description |
|--------|-------------|
| `validate_log` | Path to validation log |
| `template_dir` | Directory of rendered templates |
| `rbac_file` | Generated RBAC YAML |
| `configmap_file` | Generated ConfigMap YAML |
| `bundle_file` | Generated bundle YAML |
| `init_dir` | Directory containing example pack |

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

