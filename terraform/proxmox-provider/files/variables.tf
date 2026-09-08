variable "proxmox_api_url" {
  description = "Proxmox API URL, including the /api2/json suffix."
  type        = string
<%- if proxmox_api_url %>
  default     = "<< proxmox_api_url >>"
<%- endif %>
}


variable "proxmox_skip_tls_verify" {
  description = "Skip Proxmox TLS certificate verification. Use only for self-signed lab endpoints when a CA bundle is not available."
  type        = bool
  default     = << proxmox_skip_tls_verify | lower >>
}
