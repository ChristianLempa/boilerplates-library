# AGENTS.md

Guidance for AI agents working in this repository.

## Repository Purpose

This repository is the canonical `0.2.0+` boilerplates template library consumed by the `boilerplates` CLI.

## Validation

- Always validate template changes with the `boilerplates` CLI from this repository root.
- The validate command requires either one template slug or `--all`.
- Template/Jinja validation always runs.
- Add `--semantic` to render the dependency matrix and run semantic checks for every generated case.
- Add `--kind` to also run the kind-specific validator when a local validator tool is available. If no applicable validator or rendered kind files are available, the result may be reported as `skip` with a warning.
- For a specific template, run:
  - `boilerplates <kind> validate <template-slug> --semantic --kind`
- For every template of a kind, run:
  - `boilerplates <kind> validate --all --semantic --kind`
- Example commands:
  - `boilerplates compose validate whoami --semantic --kind`
  - `boilerplates compose validate --all --semantic --kind`
  - `boilerplates kubernetes validate core-deployment --semantic --kind`
  - `boilerplates kubernetes validate --all --semantic --kind`
  - `boilerplates terraform validate cloudflare-dns-record --semantic --kind`
  - `boilerplates terraform validate --all --semantic --kind`
- After changing templates, run validation for every affected kind before finishing.

## Local Config

- This repository includes a local `config.yaml`.
- The local `config.yaml` must point to this checkout as a `static` library so validation reads this repository directly.
- Do not validate against the git-synced library under `~/.config/boilerplates/libraries/...`.
- Run validation from the repo root so `boilerplates` picks up `./config.yaml` instead of the global config.
