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


  pm_tls_insecure = var.proxmox_skip_tls_verify
}
