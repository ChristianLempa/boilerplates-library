data "netbird_network" "router_network" {
  name = "<< network_name >>"
}

<%- if router_target_mode == "peer" %>
data "netbird_peer" "router_peer" {
  name = "<< peer_name >>"
}

<%- endif %>
<%- if router_target_mode == "peer_groups" %>
locals {
  router_peer_group_names = [
    for name in split(",", "<< peer_group_names >>") : trimspace(name)
    if trimspace(name) != ""
  ]
}

data "netbird_group" "router_peer_groups" {
  for_each = toset(local.router_peer_group_names)
  name     = each.value
}

<%- endif %>
resource "netbird_network_router" "network_router" {
  network_id  = data.netbird_network.router_network.id
  enabled     = << router_enabled | lower >>
  masquerade  = << router_masquerade | lower >>
  metric      = << router_metric >>
<%- if router_target_mode == "peer" %>
  peer        = data.netbird_peer.router_peer.id
<%- endif %>
<%- if router_target_mode == "peer_groups" %>
  peer_groups = [for name in local.router_peer_group_names : data.netbird_group.router_peer_groups[name].id]
<%- endif %>
}
