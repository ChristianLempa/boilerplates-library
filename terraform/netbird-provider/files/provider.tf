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
  management_url = trimsuffix("<< netbird_management_url >>", "/")
<%- if netbird_tenant_account %>
  tenant_account = "<< netbird_tenant_account >>"
<%- endif %>
}
