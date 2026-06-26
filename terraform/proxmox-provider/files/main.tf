terraform {
  required_version = "<< terraform_required_version >>"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "<< proxmox_provider_version >>"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.proxmox_api_url
<%- if proxmox_api_token_enabled %>

  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
<%- endif %>

  pm_tls_insecure = var.proxmox_skip_tls_verify
}
