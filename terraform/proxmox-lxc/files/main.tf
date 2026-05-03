resource "proxmox_lxc" "<< resource_name >>" {
  hostname     = "<< hostname >>"
<%- if description %>
  description  = "<< description >>"
<%- endif %>
  target_node  = "<< target_node >>"
  unprivileged = << unprivileged | lower >>
  ostemplate   = "<< ostemplate >>"

  cores  = << cores >>
  swap   = << swap_mb >>
  memory = << memory_mb >>

  start = << start_container | lower >>

  rootfs {
    storage = "<< rootfs_storage >>"
    size    = "<< rootfs_size_gb >>G"
  }

  nameserver = "<< nameserver >>"
<%- if searchdomain %>
  searchdomain = "<< searchdomain >>"
<%- endif %>

  network {
    name   = "<< network_name >>"
    bridge = "<< bridge >>"
    ip     = "<< ip_address >>"
  }

  lifecycle {
    ignore_changes = [
      rootfs,
      network,
      cmode
    ]
  }
}
