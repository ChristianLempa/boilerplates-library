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

  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  boot         = "c"
  boot_wait    = "<< boot_wait >>"
  communicator = "ssh"

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
  sources = [
    "source.proxmox-iso.<< packer_source_name >>"
  ]

  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo sed -i 's/^GRUB_CMDLINE_LINUX=\\\"/GRUB_CMDLINE_LINUX=\\\"net.ifnames=0 biosdevname=0 /' /etc/default/grub",
      "sudo update-grub",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/cloud/cloud.cfg.d/00-subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo sync"
    ]
  }

  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }
}
