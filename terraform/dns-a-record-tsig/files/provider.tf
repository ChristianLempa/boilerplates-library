terraform {
  required_version = ">= 0.13.0"

  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = "3.5.0"
    }
  }
}

provider "dns" {
  update {
    server        = "<< dns_server >>"
    key_name      = "tsig-key."
    key_algorithm = "hmac-sha256"
    key_secret    = "<< dns_server_tsig_key_secret >>"
  }
}
