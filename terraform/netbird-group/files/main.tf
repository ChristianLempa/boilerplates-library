<%- if peer_names %>
locals {
  netbird_group_peer_names = [
    for name in split(",", "<< peer_names >>") : trimspace(name)
    if trimspace(name) != ""
  ]
}

data "netbird_peer" "group_peers" {
  for_each = toset(local.netbird_group_peer_names)
  name     = each.value
}

<%- endif %>
<%- if resource_lookups %>
locals {
  netbird_group_resource_items = [
    for item in split(";", "<< resource_lookups >>") : trimspace(item)
    if trimspace(item) != ""
  ]
  netbird_group_resource_lookup_map = {
    for item in local.netbird_group_resource_items :
    item => {
      network = trimspace(split("|", item)[0])
      name    = trimspace(split("|", item)[1])
    }
  }
  netbird_group_resource_network_names = distinct([
    for lookup in values(local.netbird_group_resource_lookup_map) : lookup.network
  ])
}

data "netbird_network" "group_resource_networks" {
  for_each = toset(local.netbird_group_resource_network_names)
  name     = each.value
}

data "netbird_network_resource" "group_resources" {
  for_each   = local.netbird_group_resource_lookup_map
  network_id = data.netbird_network.group_resource_networks[each.value.network].id
  name       = each.value.name
}

<%- endif %>
resource "netbird_group" "group" {
  name = "<< group_name >>"
<%- if peer_names %>
  peers = [for name in local.netbird_group_peer_names : data.netbird_peer.group_peers[name].id]
<%- endif %>
<%- if resource_lookups %>
  resources = [for item in local.netbird_group_resource_items : data.netbird_network_resource.group_resources[item].id]
<%- endif %>
}
