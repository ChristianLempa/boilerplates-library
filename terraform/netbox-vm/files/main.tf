data "netbox_cluster" "<< resource_name >>_cluster" {
  name = "<< cluster_name >>"
}

<%- if site_name %>
data "netbox_site" "<< resource_name >>_site" {
  name = "<< site_name >>"
}
<%- endif %>

<%- if device_name %>
data "netbox_devices" "<< resource_name >>_device_lookup" {
  limit = 1

  filter {
    name  = "name"
    value = "<< device_name >>"
  }
}
<%- endif %>

resource "netbox_virtual_machine" "<< resource_name >>" {
  name       = "<< vm_name >>"
  cluster_id = data.netbox_cluster.<< resource_name >>_cluster.id
<%- if site_name %>
  site_id    = data.netbox_site.<< resource_name >>_site.id
<%- endif %>
  status     = "<< status >>"
<%- if device_name %>
  device_id  = data.netbox_devices.<< resource_name >>_device_lookup.devices[0].device_id
<%- endif %>
<%- if resources_enabled %>
  vcpus      = << vcpus >>
  memory     = << memory_mb >>
  disk       = << disk_gb >>
<%- endif %>
<%- if description_enabled %>
  comments   = "<< description_text >>"
<%- endif %>

}

<%- if ipam_enabled %>
resource "netbox_interface" "<< resource_name >>_interface" {
  name               = "<< interface_name >>"
  virtual_machine_id = netbox_virtual_machine.<< resource_name >>.id
}

resource "netbox_ip_address" "<< resource_name >>_ip" {
  ip_address   = "<< primary_ip4 >>"
  status       = "active"
  <%- if dns_name %>
  dns_name     = "<< dns_name >>"
  <%- endif %>
  interface_id = netbox_interface.<< resource_name >>_interface.id
  object_type  = "virtualization.vminterface"
}

resource "netbox_primary_ip" "<< resource_name >>_primary_ip" {
  ip_address_id      = netbox_ip_address.<< resource_name >>_ip.id
  virtual_machine_id = netbox_virtual_machine.<< resource_name >>.id
}
<%- endif %>
