# Deployment credentials

Boilerplates renders ordinary configuration and credential references only. Never enter credential material into ordinary template values, URL fields, arbitrary configuration fragments, generated ZIPs, or managed artifacts. Credentials are resolved by the deployment tool after generation, outside Boilerplates. `.env` and `.env.secret.*` output files, secret variable types, and generator metadata have been removed.

## Compose and Swarm

Export each `${NAME:?Set NAME}` variable in the process running Compose. These references deliberately fail when unset or empty. `${NAME:-value}` supplies an overridable, non-sensitive default from ordinary customization. Enable optional integration toggles before supplying their required credentials. Existing deployments must retain their deployed encryption keys and database credentials when upgrading.

Do not save the output of an interpolating `docker compose config` invocation back into the artifact: it contains runtime values. Swarm does not load Compose `.env` files automatically; export the required values in the deployment process. Provision every `external: true` Swarm secret separately before stack deployment, using the exact name rendered in the stack. Traefik uses service-prefixed token/token_key/consumer_key secrets or an AWS credentials secret; Pi-hole and n8n likewise reference existing Swarm secrets.

Additional deployment requirements:

- GitLab uses Ruby `ENV.fetch` with `GITLAB_ROOT_PASSWORD`, and optional `GITLAB_OIDC_CLIENT_SECRET` / `GITLAB_SMTP_PASSWORD`, passed through Compose.
- GitLab Runner mounts the externally provisioned file named by `GITLAB_RUNNER_CONFIG_FILE`. Register/configure the runner outside Boilerplates; the file must contain the runner token and settings.
- BIND mounts an externally provisioned TSIG key file from `BIND_TSIG_KEY_FILE` when TSIG is enabled. It must declare `tsig-transfer-key` using `hmac-sha256`.
- NetBird mounts `NETBIRD_CONFIG_FILE`. Use the generated non-sensitive `config/config.yaml` as a base outside managed output and supply `server.authSecret` and `server.store.encryptionKey` through your secret-management workflow. The base is not the active mounted configuration.
- Kestra uses its native `DATASOURCES_POSTGRES_PASSWORD` environment override; its YAML retains ordinary configuration. The former optional `.env` mount is removed.
- Infisical requires `DB_CONNECTION_URI` and `REDIS_URL` as complete runtime connection URLs. With bundled services, match the separately supplied PostgreSQL/Redis passwords and the rendered service hostnames. URL-encode credentials where required. No URI credential is defaulted or rendered by Boilerplates.
- Existing composed PostgreSQL URLs in Dockhand and Komodo still require credentials valid in a URI; provide URL-safe credentials. These references resolve only during deployment.

The complete per-template list of required Compose/Swarm environment names follows. Conditional branches only need the variables used in the rendered output.

| Template | Deployment environment |
| --- | --- |
| `compose/arcane` | `ARCANE_ENCRYPTION_KEY`, `ARCANE_JWT_SECRET`, `ARCANE_OIDC_CLIENT_SECRET` |
| `compose/arcane-agent` | `ARCANE_AGENT_TOKEN` |
| `compose/authentik` | `AUTHENTIK_BOOTSTRAP_PASSWORD`, `AUTHENTIK_SECRET_KEY`, `DATABASE_PASSWORD`, `EMAIL_PASSWORD` |
| `compose/bind9` | `BIND_TSIG_KEY_FILE` |
| `compose/checkmk` | `CMK_PASSWORD` |
| `compose/cloudflared` | `TUNNEL_TOKEN` |
| `compose/crowdsec` | `BOUNCER_KEY_TRAEFIK`, `ENROLL_KEY` |
| `compose/dockhand` | `DATABASE_PASSWORD`, `ENCRYPTION_KEY` |
| `compose/forgejo` | `DATABASE_PASSWORD` |
| `compose/gitea` | `DATABASE_PASSWORD` |
| `compose/gitlab` | `GITLAB_OIDC_CLIENT_SECRET`, `GITLAB_ROOT_PASSWORD`, `GITLAB_SMTP_PASSWORD` |
| `compose/gitlab-runner` | `GITLAB_RUNNER_CONFIG_FILE` |
| `compose/grafana` | `GRAFANA_DB_PASSWORD`, `GRAFANA_OAUTH_CLIENT_SECRET` |
| `compose/infisical` | `AUTH_SECRET`, `DB_CONNECTION_URI`, `ENCRYPTION_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `REDIS_URL`, `SMTP_PASSWORD` |
| `compose/influxdb` | `INFLUXDB_INIT_ADMIN_TOKEN`, `INFLUXDB_INIT_PASSWORD` |
| `compose/kestra` | `DATASOURCES_POSTGRES_PASSWORD` |
| `compose/komodo` | `KOMODO_DATABASE_PASSWORD`, `KOMODO_JWT_SECRET` |
| `compose/mariadb` | `MARIADB_PASSWORD`, `MARIADB_ROOT_PASSWORD` |
| `compose/n8n` | `DATABASE_PASSWORD`, `N8N_ENCRYPTION_KEY` |
| `compose/netbird` | `NETBIRD_CONFIG_FILE` |
| `compose/netbox` | `DATABASE_PASSWORD`, `EMAIL_PASSWORD`, `NETBOX_SECRET_KEY`, `REDIS_PASSWORD` |
| `compose/nextcloud` | `DATABASE_PASSWORD`, `NEXTCLOUD_ADMIN_PASSWORD` |
| `compose/openwebui` | `OAUTH_CLIENT_SECRET` |
| `compose/passbolt` | `DATABASE_PASSWORD`, `EMAIL_PASSWORD` |
| `compose/pihole` | `WEBPASSWORD` |
| `compose/postgres` | `POSTGRES_PASSWORD` |
| `compose/renovate` | `MEND_RNV_GITLAB_PAT`, `MEND_RNV_LICENSE_KEY`, `MEND_RNV_WEBHOOK_SECRET` |
| `compose/semaphoreui` | `DATABASE_PASSWORD`, `SEMAPHORE_ACCESS_KEY_ENCRYPTION`, `SEMAPHORE_ADMIN_PASSWORD` |
| `compose/technitium` | `DNS_SERVER_ADMIN_PASSWORD` |
| `compose/traefik` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `CF_DNS_API_TOKEN`, `DO_AUTH_TOKEN`, `GODADDY_API_KEY`, `GODADDY_API_SECRET`, `NAMECHEAP_API_KEY`, `NETCUP_API_KEY`, `NETCUP_API_PASSWORD`, `NETCUP_CUSTOMER_NUMBER`, `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`, `PORKBUN_API_KEY`, `PORKBUN_SECRET_API_KEY` |
| `compose/twingate-connector` | `TWINGATE_ACCESS_TOKEN`, `TWINGATE_REFRESH_TOKEN` |
| `swarm/komodo` | `ENVIRONMENT_DATABASE_PASSWORD`, `ENVIRONMENT_JWT_SECRET` |
| `swarm/nextcloud` | `MYSQL_PASSWORD`, `NEXTCLOUD_ADMIN_PASSWORD`, `POSTGRES_PASSWORD` |
| `swarm/postgres` | `DATABASE_PASSWORD` |
| `swarm/renovate` | `GIT_TOKEN`, `LICENSE_KEY`, `WEBHOOK_SECRET` |
| `swarm/twingate-connector` | `TWINGATE_ACCESS_TOKEN`, `TWINGATE_REFRESH_TOKEN` |

## Kubernetes and Helm

The `core-secret` and `certmanager-webhook-netcup-secret` templates now create `ExternalSecret` resources rather than plaintext Kubernetes Secrets. Install External Secrets Operator with the `external-secrets.io/v1` CRD and configure the named `ClusterSecretStore` first. The generic template reads one remote secret value into `api-token`; Netcup reads the remote object's `customer-number`, `api-key`, and `api-password` properties. Existing workloads and cert-manager issuers reference the resulting Kubernetes Secret by name. The Ansible K3s post-install playbook also expects the Cloudflare Secret to exist; it no longer creates one.

Provision Helm credentials in the release namespace before installation:

| Template | Existing Secret requirements |
| --- | --- |
| Authentik | `authentik_existing_secret`: `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__PASSWORD`, and `AUTHENTIK_EMAIL__PASSWORD` when email is enabled. With bundled PostgreSQL, `database_secret_name` must hold the same `AUTHENTIK_POSTGRESQL__PASSWORD` plus `postgres-password`. |
| NetBox | `netbox_existing_secret`: `secret_key`, `password`, `api_token`, `username`, `email`, and optional `email-password` (username/email must match the ordinary superuser settings). `database_secret_name`: `password` and, for bundled PostgreSQL, `postgres-password`. `redis_secret_name`: `redis-password`. |
| Infisical | `infisical_secret_name`: `AUTH_SECRET`, `ENCRYPTION_KEY`, `REDIS_URL`, and optional `SMTP_PASSWORD`. `database_secret_name`: `DB_CONNECTION_URI`. Deploy PostgreSQL and Redis separately; bundled modes were removed because chart 1.9.0 embeds password-based connection URLs instead of referencing Secrets. Ordinary site/email settings remain in values. |

Helm values do not perform shell interpolation. Secret names are ordinary customization; the credentials live outside generated values. Chart versions must support the authored existing-secret fields; NetBox retains the PostgreSQL/Redis-based chart layout (5.x), not the newer Valkey chart layout. Confirm the selected chart version before upgrading a release.

References: [Authentik chart values](https://github.com/goauthentik/helm/blob/main/charts/authentik/values.yaml), [NetBox PostgreSQL/Redis chart values](https://github.com/netbox-community/netbox-chart/blob/netbox-5.0.0/charts/netbox/values.yaml), [Kestra environment configuration](https://kestra.io/docs/configuration/configuration-basics).

## Ansible, Python, Bash, and OpenTofu

Checkmk playbooks read `CHECKMK_PASSWORD` from the Ansible controller environment with `default=undef()` and suppress credential-bearing task output. They require Ansible core 2.13+ and the Checkmk collection. Python's disk monitor reads `DISCORD_WEBHOOK_URL` from its process environment. Bash database backup templates retain their configurable password environment-variable names; no password is generated.

The GitLab provider reads `GITLAB_TOKEN`; the Telmate Proxmox provider reads `PM_API_TOKEN_ID` and `PM_API_TOKEN_SECRET`. These are provider-native environment variables. Resource templates requiring values use native sensitive input variables without defaults: supply `TF_VAR_ci_variable_value` for GitLab project/group CI variables, `TF_VAR_webhook_token` for GitLab project hooks, and `TF_VAR_auth_password` or `TF_VAR_auth_pin` for the selected NetBird authentication mode. Use the appropriate provider configuration alongside resource-only templates. These runtime variables do not become Boilerplates inputs; protect downstream IaC state and plans separately.

## Packer

Supply `PKR_VAR_proxmox_api_token_secret` and `PKR_VAR_ssh_password` at build time. Ubuntu also requires `PKR_VAR_admin_password_hash` matching the build user's password. The template engine never sees these values. The generated `.pkrtpl` files contain Packer-native placeholders; `templatefile` and `http_content` resolve them only while Packer runs. NixOS/Talos boot commands likewise use Packer-native `var.ssh_password` interpolation. Keep build logs, the installer HTTP endpoint, and any downstream runtime files outside managed artifacts.

## Compatibility and verification

Removed input names and generators cannot be imported as ordinary credential values. Existing template revisions, ZIPs, artifact revisions, and deployed resources are not retroactively sanitized by editing this checkout. Re-render with the new schemas and remove old generated credential files through the application's supported ownership workflow. Provision external references before switching deployments, preserve existing encryption keys, and rotate credentials that were previously exposed.

Run `python3 scripts/check-credentials.py`, then the [kind-specific validation commands](scripts/credential-validation.md). Compose/Packer validation requires non-production test values for the required environment variables; never use real deployment credentials in validation logs. Helm values-only and custom Kubernetes resource checks can be skipped by the installed CLI even when Helm/kubectl are installed; template/schema checks alone do not verify a live deployment.
