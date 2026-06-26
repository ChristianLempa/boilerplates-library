variable "proxmox_api_url" {
  description = "Proxmox API URL, including the /api2/json suffix."
  type        = string
<%- if proxmox_api_url %>
  default     = "<< proxmox_api_url >>"
<%- endif %>
}

<%- if proxmox_api_token_enabled %>
variable "proxmox_api_token_id" {
  description = "Proxmox API token ID, for example root@pam!terraform."
  type        = string
<%- if proxmox_api_token_id %>
  default     = "<< proxmox_api_token_id >>"
<%- endif %>
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret. Prefer TF_VAR_proxmox_api_token_secret or another secret backend for real deployments."
  type        = string
  sensitive   = true
<%- if proxmox_api_token_secret %>
  default     = "<< proxmox_api_token_secret >>"
<%- endif %>
}

<%- endif %>
variable "proxmox_skip_tls_verify" {
  description = "Skip Proxmox TLS certificate verification. Use only for self-signed lab endpoints when a CA bundle is not available."
  type        = bool
  default     = << proxmox_skip_tls_verify | lower >>
}
