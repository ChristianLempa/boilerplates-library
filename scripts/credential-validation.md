# Credential boundary validation — 2026-09-08

Scope: library checkout only, on `testing`, without commit or push. Removed 129 credential-bearing inputs across 62 changed manifests, including secret types/generators and ordinary Packer, GitLab webhook, and GitLab CI variable inputs. Preserved pre-existing `.gitignore`, AGENTS schema guidance, deleted `docs` link, and `plans` changes.

## Checks

All commands ran from the library root using the existing `config.yaml` static-library path. Required Compose environment variables were assigned the non-credential sentinel `validation-only` (external file references used an absolute test path); Packer used `PKR_VAR_proxmox_api_token_secret`, `PKR_VAR_ssh_password`, and `PKR_VAR_admin_password_hash` with test-only values. No deployment, provider apply, webhook request, or secret creation was performed.

| Check | Result |
| --- | --- |
| `python3 scripts/check-credentials.py` | Passed for the entire library: no secret schemas/generators, removed credential inputs/render references, dangling needs, generated `.env` files, literal Kubernetes Secret resources, or credential environment defaults. |
| `git diff --check` | Passed. |
| `boilerplates compose validate --all --semantic --kind` | All 43 templates passed, including Docker Compose config validation; Grafana/OpenWebUI rerun after retaining public client ID customization. |
| `boilerplates swarm validate --all --semantic --kind` | All 10 templates passed. |
| `boilerplates ansible validate --all --semantic --kind` | All 10 templates passed. |
| `boilerplates packer validate --all --semantic --kind` | All 7 templates passed with runtime test variables. |
| `boilerplates helm validate --all --semantic --kind` | All 9 templates passed template/semantic validation; values-only kind checks skipped by the CLI. Infisical rerun after removing incompatible bundled modes. |
| `boilerplates kubernetes validate --all --semantic --kind` | All 20 templates passed template/semantic validation; kind checks skipped by the CLI. `kubeconform` is unavailable; kubectl is installed. |
| `boilerplates python validate --all --semantic --kind` | The one template passed; CLI has no Python kind validator. Rendered Python compiled and a read-only execution check proved missing environment fails and a sentinel is read only at runtime; no webhook sent. |
| `boilerplates bash validate --all --semantic --kind` | All 3 templates passed; CLI has no Bash kind validator. Only credential examples in help text changed. |
| `boilerplates terraform validate <slug> --kind` | GitLab provider, Proxmox provider, GitLab project hook, and GitLab project/group CI variable templates passed. |
| NetBird reverse-proxy resource template | CLI template/semantic checks passed, but standalone kind validation could not resolve the inferred `hashicorp/netbird` provider. Generated password and PIN cases were checked separately with an external `required_providers` configuration for `registry.terraform.io/netbirdio/netbird` 0.0.9 and passed `tofu init -backend=false -input=false` plus `tofu validate`. |
| Infisical native Helm render | Generated values successfully rendered against chart 1.9.0 using `helm template`; no Secret resource or embedded database credential emitted. |

## Deployment compatibility

See [CREDENTIALS.md](../CREDENTIALS.md) for deployment environment names, existing Secret keys, removed `.env` behavior, External Secrets Operator requirements, and Packer runtime interpolation. Infisical Helm now requires separately deployed PostgreSQL/Redis because the bundled chart constructs literal credential URLs. Kubernetes Secret-generating templates now author ExternalSecret references; they require an existing ClusterSecretStore and External Secrets Operator with the v1 CRD.

Application frontend/backend enforcement is owned by other dispatched workers. This library audit cannot sanitize existing immutable revisions, old ZIPs, runtime state, or arbitrary credential text that a user deliberately inserts into an ordinary string field; previously exposed credentials require external cleanup/rotation.
