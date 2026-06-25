terraform {
  required_version = "<< terraform_required_version >>"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "<< gitlab_provider_version >>"
    }
  }
}

provider "gitlab" {
<%- if gitlab_base_url %>
  base_url = var.gitlab_base_url
<%- endif %>
<%- if gitlab_token_enabled %>
  token    = var.gitlab_token
<%- endif %>
<%- if gitlab_cacert_file %>
  cacert_file = var.gitlab_cacert_file
<%- endif %>
}
