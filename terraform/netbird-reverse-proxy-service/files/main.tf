<%- if domain_mode == "free" %>
data "netbird_reverse_proxy_domain" "free" {
  type = "free"
}

<%- endif %>
<%- if domain_mode == "custom" %>
data "netbird_reverse_proxy_domain" "custom" {
  domain    = "<< custom_domain >>"
  validated = true
}

<%- endif %>
<%- if target_type == "peer" %>
data "netbird_peer" "target_peer" {
  name = "<< target_peer_name >>"
}

<%- endif %>
<%- if target_type == "host" %>
data "netbird_network" "target_network" {
  name = "<< target_network_name >>"
}

data "netbird_network_resource" "target_resource" {
  network_id = data.netbird_network.target_network.id
  name       = "<< target_host_name >>"
}

<%- endif %>
<%- if target_type == "domain" %>
data "netbird_network" "target_network" {
  name = "<< target_network_name >>"
}

data "netbird_network_resource" "target_resource" {
  network_id = data.netbird_network.target_network.id
  name       = "<< target_domain_name >>"
}

<%- endif %>
<%- if target_type == "subnet" %>
data "netbird_network" "target_network" {
  name = "<< target_network_name >>"
}

data "netbird_network_resource" "target_resource" {
  network_id = data.netbird_network.target_network.id
  name       = "<< target_subnet_name >>"
}

<%- endif %>
<%- if target_type != "peer" %>
locals {
  reverse_proxy_target_resource_type = can(cidrnetmask(data.netbird_network_resource.target_resource.address)) ? "subnet" : (length(regexall(":", data.netbird_network_resource.target_resource.address)) > 0 ? "host" : (length(regexall("[A-Za-z*]", data.netbird_network_resource.target_resource.address)) > 0 ? "domain" : "host"))
}

<%- endif %>
<%- if bearer_distribution_group_names %>
locals {
  reverse_proxy_bearer_group_names = [
    for name in split(",", "<< bearer_distribution_group_names >>") : trimspace(name)
    if trimspace(name) != ""
  ]
}

data "netbird_group" "bearer_distribution_groups" {
  for_each = toset(local.reverse_proxy_bearer_group_names)
  name     = each.value
}

<%- endif %>
resource "netbird_reverse_proxy_service" "reverse_proxy_service" {
  name = "<< service_name >>"
<%- if domain_mode == "free" %>
  domain = data.netbird_reverse_proxy_domain.free.domain
<%- endif %>
<%- if domain_mode == "custom" %>
  domain = data.netbird_reverse_proxy_domain.custom.domain
<%- endif %>
  enabled           = << service_enabled | lower >>
  pass_host_header  = << pass_host_header | lower >>
  rewrite_redirects = << rewrite_redirects | lower >>

  targets = [{
<%- if target_type == "peer" %>
    target_id   = data.netbird_peer.target_peer.id
<%- endif %>
<%- if target_type == "host" %>
    target_id   = data.netbird_network_resource.target_resource.id
<%- endif %>
<%- if target_type == "domain" %>
    target_id   = data.netbird_network_resource.target_resource.id
<%- endif %>
<%- if target_type == "subnet" %>
    target_id   = data.netbird_network_resource.target_resource.id
<%- endif %>
<%- if target_type == "peer" %>
    target_type = "peer"
<%- endif %>
<%- if target_type != "peer" %>
    target_type = local.reverse_proxy_target_resource_type
<%- endif %>
    port        = << target_port >>
    protocol    = "<< target_protocol >>"
    enabled     = << target_enabled | lower >>
<%- if target_host %>
    host        = "<< target_host >>"
<%- endif %>
<%- if not target_host and target_type != "peer" %>
    host        = local.reverse_proxy_target_resource_type == "subnet" ? split("/", data.netbird_network_resource.target_resource.address)[0] : null
<%- endif %>
<%- if target_path %>
    path        = "<< target_path >>"
<%- endif %>
  }]

  auth = {
<%- if auth_mode == "link" %>
    link_auth = {
      enabled = true
    }
<%- endif %>
<%- if auth_mode == "password" %>
    password_auth = {
      enabled  = true
      password = "<< auth_password >>"
    }
<%- endif %>
<%- if auth_mode == "pin" %>
    pin_auth = {
      enabled = true
      pin     = "<< auth_pin >>"
    }
<%- endif %>
<%- if auth_mode == "bearer" %>
    bearer_auth = {
      enabled = true
<%- if bearer_distribution_group_names %>
      distribution_groups = [for name in local.reverse_proxy_bearer_group_names : data.netbird_group.bearer_distribution_groups[name].id]
<%- endif %>
    }
<%- endif %>
  }
}
