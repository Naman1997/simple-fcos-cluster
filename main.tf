terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.6.14"
    }
  }
}

# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "nixos" {
  name = "nixos"
  type = "dir"
  path = "/tmp/terraform-provider-libvirt-pool-nixos"
}

# We fetch the 22.05 nixos release image from their mirrors
resource "libvirt_volume" "nixos-iso" {
  name   = "nixos-iso"
  pool   = libvirt_pool.nixos.name
  source = "./base-img/nixos.qcow2"
  format = "qcow2"
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = data.template_file.user_data.rendered
  pool      = libvirt_pool.nixos.name
}

# Create the machine
resource "libvirt_domain" "domain-nixos" {
  name      = "nixos-terraform"
  memory    = "4096"
  vcpu      = 2
  cloudinit = libvirt_cloudinit_disk.commoninit.id

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.nixos-iso.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  # connection {
  #   type     = "ssh"
  #   user     = "root"
  #   password = ""
  #   host     = network_interface.default.addresses.0
  # }

  # provisioner "file" {
  #   source      = "./kubernetes/configuration.nix"
  #   destination = "/etc/nixos/configuration.nix"

  #   connection {
  #     type        = "ssh"
  #     user        = "root"
  #     password = ""
  #     host     = network_interface.default.addresses.0
  #   }
  # }

  # provisioner "file" {
  #   source      = "./kubernetes/kubernetes.nix"
  #   destination = "/etc/nixos/kubernetes.nix"

  #   connection {
  #     type        = "ssh"
  #     user        = "root"
  #     password = ""
  #     host     = network_interface.default.addresses.0
  #   }
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "nixos-generate-config",
  #     "nixos-rebuild switch",
  #     "reboot",
  #   ]
  # }
}