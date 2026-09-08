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
  default = "<< proxmox_api_url >>"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "<< proxmox_api_token_id >>"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "ssh_username" {
  type    = string
  default = "nixos"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "http_interface" {
  type    = string
  default = "<< http_interface >>"
}
