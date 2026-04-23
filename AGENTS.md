# AGENTS.md

Guidance for AI agents working in this repository.

## Repository Purpose

This repository is the canonical `0.2.0+` boilerplates template library consumed by the `boilerplates` CLI.

## Validation

- Always validate template changes with the `boilerplates` CLI from this repository root.
- Use `boilerplates <kind> validate` to validate all templates for a kind.
- Example commands:
  - `boilerplates compose validate`
  - `boilerplates swarm validate`
  - `boilerplates kubernetes validate`
- After changing templates, run validation for every affected kind before finishing.

## Local Config

- This repository includes a local `config.yaml`.
- The local `config.yaml` must point to this checkout as a `static` library so validation reads this repository directly.
- Do not validate against the git-synced library under `~/.config/boilerplates/libraries/...`.
- Run validation from the repo root so `boilerplates` picks up `./config.yaml` instead of the global config.
