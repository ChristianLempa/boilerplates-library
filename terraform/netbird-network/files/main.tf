resource "netbird_network" "network" {
  name = "<< network_name >>"
<%- if network_description %>
  description = "<< network_description >>"
<%- endif %>
}
