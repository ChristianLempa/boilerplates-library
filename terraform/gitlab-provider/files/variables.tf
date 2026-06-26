<%- if gitlab_base_url %>
variable "gitlab_base_url" {
  description = "GitLab API base URL. For self-managed GitLab, include the /api/v4/ suffix."
  type        = string
  default     = "<< gitlab_base_url >>"
}

<%- endif %>
<%- if gitlab_token_enabled %>
variable "gitlab_token" {
  description = "GitLab access token. Prefer TF_VAR_gitlab_token or another secret backend for real deployments. Disable this variable to rely on provider environment variables like GITLAB_TOKEN."
  type        = string
  sensitive   = true
<%- if gitlab_token %>
  default     = "<< gitlab_token >>"
<%- endif %>
}

<%- endif %>
<%- if gitlab_cacert_file %>
variable "gitlab_cacert_file" {
  description = "Path to a custom CA certificate bundle used by the GitLab provider."
  type        = string
  default     = "<< gitlab_cacert_file >>"
}

<%- endif %>
variable "gitlab_skip_tls_verify" {
  description = "Skip GitLab TLS certificate verification. Use only for self-signed lab endpoints when a CA bundle is not available."
  type        = bool
  default     = << gitlab_skip_tls_verify | lower >>
}
