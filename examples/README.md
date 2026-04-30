# Orkestra Action Examples

This directory contains ready-to-use GitHub Actions workflows that demonstrate how to use the Orkestra CI Action in different scenarios.

Each example is intentionally small, focused, and composable. You can copy them as-is, or adapt them to your own repositories and pipelines.

## Structure

- `validate.yml`  
  Minimal workflow that runs `ork validate` against a Katalog.

- `template.yml`  
  Renders templates from a Katalog and exposes the rendered directory as an output.

- `generate-bundle.yml`  
  Generates an Orkestra bundle from a Katalog and makes the bundle path available to downstream steps.

- `init.yml`  
  Runs `ork init` to generate an example pack and inspects the output.

- `matrix.yml` (optional, if you add it)  
  Demonstrates running validation and bundle generation across multiple Katalogs and/or Ork CLI versions using a matrix strategy.

## Conventions

All examples follow these conventions:

- Use `orkspace/orkestra-action@v1` as the action reference.
- Assume `katalog.yaml` or `komposer.yaml` is present at the repository root unless otherwise specified.
- Keep each workflow focused on a single concern (validate, template, generate, init, matrix, etc.).
- Prefer explicit `id` fields on steps that consume action outputs.

## How to use these examples

1. Copy the desired example file into your repository under `.github/workflows/`.
2. Adjust paths (for `katalog`, charts, or manifests) to match your project layout.
3. Commit and push to trigger the workflow on the configured events (usually `push` or `pull_request`).
4. Iterate: enable additional flags (e.g. `generate-bundle: true`) or combine steps as your pipeline grows.

These examples are designed to be a starting point, not a constraint. Treat them as building blocks for your own Orkestra-powered CI and GitOps workflows.
