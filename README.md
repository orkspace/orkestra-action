# Orkestra E2E Action

<div align="center">
    <img src="logo.svg" width="140" alt="Orkestra Logo">
</div>

A minimal GitHub Action that installs the `ork` CLI and runs `ork e2e` against your operator.

---

## How it works

1. Installs the `ork` CLI (pinned version or latest)
2. Runs `ork e2e -f <e2e-file>`

That's it. All cluster lifecycle, bundle generation, Helm install, and resource verification is handled by `ork e2e` — no extra configuration needed in CI.

---

## Usage

```yaml
- uses: orkspace/ork-action@v1
  with:
    e2e-file: e2e.yaml
```

The `e2e.yaml` file in your repository drives everything — cluster provider, CRD to test, CR to apply, and expectations to assert.

---

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `e2e-file` | `e2e.yaml` | Path to the `e2e.yaml` spec file |
| `ork-version` | `latest` | Version of the `ork` CLI to install |
| `keep-cluster` | `false` | Keep the kind cluster after the test (useful for debugging) |
| `cluster` | `""` | Use an existing kubectl context instead of creating a new cluster |

---

## Example: single operator

```yaml
name: E2E

on:
  push:
    branches: [main]
  pull_request:

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: orkspace/ork-action@v1
        with:
          e2e-file: e2e.yaml
```

---

## Example: matrix across multiple operators

```yaml
name: E2E

on:
  push:
    branches: [main]
  pull_request:

jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        example:
          - examples/beginner/01-hello-website
          - examples/beginner/02-with-service
          - examples/advanced/09-hooks

    defaults:
      run:
        working-directory: ${{ matrix.example }}

    steps:
      - uses: actions/checkout@v4

      - uses: orkspace/ork-action@v1
        with:
          e2e-file: e2e.yaml
```

---

## The `e2e.yaml` spec

Every operator has three canonical files — `katalog.yaml`, `crd.yaml`, `cr.yaml`. The `e2e.yaml` wires them together and declares what to assert:

```yaml
apiVersion: orkestra.orkspace.io/v1
kind: E2E
metadata:
  name: hello-website-e2e
  description: Verify the hello-website operator deploys and cleans up

spec:
  katalog: ./katalog.yaml
  crd: ./crd.yaml
  cr: ./cr.yaml

  cluster:
    provider: kind
    name: ork-e2e
    reuse: false

  expect:
    - name: Deployment created
      after: cr-applied
      timeout: 60s
      resources:
        - kind: Deployment
          namespace: default
          ready: true

    - name: Deployment removed on delete
      after: cr-deleted
      timeout: 30s
      resources:
        - kind: Deployment
          namespace: default
          count: 0
```

Validate your `e2e.yaml` locally before pushing:

```sh
ork validate -f e2e.yaml
```

---

## License

[Apache 2.0](./LICENSE)
