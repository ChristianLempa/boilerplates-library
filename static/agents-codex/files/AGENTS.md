# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

Project name: << project_name >>

## Scope and precedence

- This file applies to the repository tree rooted at the directory containing this `AGENTS.md` file.
- More deeply nested `AGENTS.md` files may add or override instructions for their subtrees.

## Repository map

Use this as the first place to understand where things live. Replace TODOs with the actual project structure as it becomes clear.

<%- if source_dir %>
- Source: `<< source_dir >>` - main application or library source code.
<%- endif %>
<%- if tests_dir %>
- Tests: `<< tests_dir >>` - automated tests, fixtures, and test utilities.
<%- endif %>
<%- if docs_dir %>
- Docs: `<< docs_dir >>` - project documentation, architecture notes, and user/developer guides.
<%- endif %>
<%- if cfg_dir %>
- Config: `<< cfg_dir >>` - configuration files, examples, defaults, or environment-specific settings.
<%- endif %>
<%- if ansible_dir %>
- Ansible: `<< ansible_dir >>` - playbooks, roles, inventories, and automation tasks.
<%- endif %>
<%- if terraform_dir %>
- Terraform: `<< terraform_dir >>` - infrastructure-as-code modules, stacks, variables, and provider configuration.
<%- endif %>
<%- if deployments_dir %>
- Deployments: `<< deployments_dir >>` - deployment manifests, environment overlays, Compose files, Helm values, or Kubernetes resources.
<%- endif %>

<%- if docs_dir  %>
## Documentation

Project documentation lives in `<< docs_dir >>`.

Agents should read the relevant docs before making changes and update docs when behavior, configuration, or workflows change.

### Documentation map

TODO: fill in

<%- endif %>
<%- if validation_enabled %>
## Validation

Run the relevant checks before finishing changes.

<%- if validation_commands %>
<< validation_commands >>
<%- else %>
AI placeholder: fill in the project-specific validation commands agents should run.

- TODO: format
- TODO: lint
- TODO: test
- TODO: build
- TODO: any template, config, or deployment validation
<%- endif %>
<%- endif %>

<%- if conventions_enabled %>
## Project conventions

<%- if rule_existing_patterns %>- Follow existing project structure, naming, and patterns before introducing new ones.
<%- endif %><% if rule_minimal_changes %>- Keep changes focused on the requested task; avoid unrelated refactors or broad rewrites.
<%- endif %><% if rule_update_docs %>- When adding or changing features, update the relevant documentation.
<%- endif %><% if rule_add_tests %>- When changing logic, add or update tests where practical.
<%- endif %>
- Do not commit secrets, tokens, private keys, or environment-specific credentials.
<% if conventions_notes %>
<< conventions_notes >>
<%- else %>- TODO: add project-specific coding style, architecture, naming, dependency, or review conventions.
<%- endif %>
<%- endif %>
