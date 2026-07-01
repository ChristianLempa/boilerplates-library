source "proxmox-iso" "<< packer_source_name >>" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = false

  node                 = "<< proxmox_node >>"
  vm_name              = "<< vm_name >>"
  template_description = "<< template_description >>"

  iso_file         = "<< iso_file >>"
  iso_storage_pool = "<< iso_storage_pool >>"
  unmount_iso      = true
  qemu_agent       = true

  scsi_controller = "virtio-scsi-pci"

  cores   = "<< cpu_cores >>"
  sockets = "<< cpu_sockets >>"
  memory  = "<< memory >>"

  cloud_init              = true
  cloud_init_storage_pool = "<< cloud_init_storage_pool >>"

  vga {
    type = "virtio"
  }

  disks {
    disk_size    = "<< disk_size >>"
    format       = "raw"
    storage_pool = "<< disk_storage_pool >>"
    type         = "virtio"
  }

  network_adapters {
    model    = "virtio"
    bridge   = "<< network_bridge >>"
    firewall = "false"
  }

  boot_command = []

  boot           = "c"
  boot_wait      = "<< boot_wait >>"
  communicator   = "ssh"
  http_directory = "http"
  http_interface = var.http_interface

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password

  ssh_timeout            = "<< ssh_timeout >>"
  ssh_pty                = true
  ssh_handshake_attempts = 15
}

build {
  name = "<< packer_source_name >>"
  sources = ["source.proxmox-iso.<< packer_source_name >>"]

  provisioner "shell" {
    inline = [
      "sudo nix-collect-garbage -d || true",
      "sudo rm -f /etc/ssh/ssh_host_* || true",
      "sudo sync"
    ]
  }
}
