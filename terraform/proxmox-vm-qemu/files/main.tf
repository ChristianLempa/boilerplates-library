resource "proxmox_vm_qemu" "<< resource_name >>" {
  name = "<< vm_name >>"
<%- if vm_id %>
  vmid = "<< vm_id >>"
<%- endif %>
<%- if description %>
  description = "<< description >>"
<%- endif %>
<%- if tags %>
  tags = "<< tags >>"
<%- endif %>
  agent         = 1
  agent_timeout = 90
  target_node   = "<< target_node >>"

  define_connection_info = false

  full_clone = << full_clone | lower >>
  clone      = "<< clone_template >>"

  onboot           = << onboot | lower >>
<%- if startup %>
  startup          = "<< startup >>"
<%- endif %>
  automatic_reboot = << automatic_reboot | lower >>

  qemu_os = "<< qemu_os >>"
  bios    = "<< bios >>"

  cpu {
    cores   = << cpu_cores >>
    sockets = << cpu_sockets >>
    type    = "<< cpu_type >>"
  }

  memory  = << memory_mb >>
  balloon = << memory_mb >>

  network {
    id     = 0
    bridge = "<< bridge >>"
    model  = "<< network_model >>"
  }

  scsihw = "virtio-scsi-pci"

  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "<< cloudinit_storage >>"
        }
      }
    }

    virtio {
      virtio0 {
        disk {
          storage   = "<< disk_storage >>"
          size      = "<< disk_size_gb >>G"
          iothread  = << disk_iothread | lower >>
          replicate = << disk_replicate | lower >>
        }
      }
    }
  }

  ipconfig0 = "<< ipconfig0 >>"
<%- if nameserver %>
  nameserver = "<< nameserver >>"
<%- endif %>
  ciuser = "<< ci_user >>"
<%- if ssh_key %>
  sshkeys = "<< ssh_key >>"
<%- endif %>
<%- if depends_on_enabled %>
  depends_on = [<< dependencies >>]
<%- endif %>
<%- if lifecycle_enabled %>

  lifecycle {
<%- if prevent_destroy %>
    prevent_destroy = true
<%- endif %>
<%- if create_before_destroy %>
    create_before_destroy = true
<%- endif %>
<%- if ignore_changes %>
    ignore_changes = [<< ignore_changes >>]
<%- endif %>
  }
<%- endif %>
}
