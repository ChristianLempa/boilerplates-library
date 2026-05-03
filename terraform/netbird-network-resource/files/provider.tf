terraform {
  required_version = ">= 1.0.0"

  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "0.0.9"
    }
  }
}

provider "netbird" {
  token          = "<< netbird_pat >>"
  management_url = "<< netbird_management_url >>"
}
