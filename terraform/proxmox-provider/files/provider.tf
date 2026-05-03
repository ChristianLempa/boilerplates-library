terraform {
  required_version = ">= 0.13.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "<< proxmox_api_url >>"
  pm_api_token_id     = "<< proxmox_api_token_id >>"
  pm_api_token_secret = "<< proxmox_api_token_secret >>"
  pm_tls_insecure     = << proxmox_tls_insecure | lower >>
}
