packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_api_url" {
  type    = string
  default = "https://proxmox.example.com:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "packer@pve!token"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
  default   = "CHANGEME"
}

variable "ssh_username" {
  type    = string
  default = "root"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "<%- if ssh_password %><< ssh_password >><%- else %>CHANGEME<%- endif %>"
}

variable "http_interface" {
  type    = string
  default = "<< http_interface >>"
}
