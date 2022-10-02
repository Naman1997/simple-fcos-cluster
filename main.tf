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
  source = "https://channels.nixos.org/nixos-22.05/latest-nixos-minimal-x86_64-linux.iso"
  # size   = 5361393152
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
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

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
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
}

# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain
