data "netbird_network" "parent_network" {
  name = "<< network_name >>"
}

<%- for group_name in group_names.split(',') %>
<%- if group_name|trim %>
data "netbird_group" "group_<< group_name|trim|replace(' ', '_')|replace('-', '_') >>" {
  name = "<< group_name|trim >>"
}

<%- endif %>
<%- endfor %>

resource "netbird_network_resource" "network_resource" {
  network_id = data.netbird_network.parent_network.id
  name       = "<< resource_name >>"
  <%- if resource_description %>
  description = "<< resource_description >>"
  <%- endif %>
  address    = "<< resource_address >>"
  groups     = [
<%- for group_name in group_names.split(',') %>
<%- if group_name|trim %>
    data.netbird_group.group_<< group_name|trim|replace(' ', '_')|replace('-', '_') >>.id,
<%- endif %>
<%- endfor %>
  ]
  enabled    = << resource_enabled | lower >>
}
