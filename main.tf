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

resource "libvirt_pool" "ubuntu" {
  name = "ubuntu"
  type = "dir"
  path = "/tmp/terraform-provider-libvirt-pool-ubuntu"
}

resource "libvirt_volume" "os_image" {
  name = "arch-os_image"
  pool = libvirt_pool.ubuntu.name
  source = "/home/naman/Documents/Github/arch-cloud-image/output-archlinux/golden-arch.qcow2"
  format = "qcow2"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "arch-qcow2" {
  name   = "arch-qcow2"
  pool   = libvirt_pool.ubuntu.name
  base_volume_id = libvirt_volume.os_image.id
  size   = 100 * 1073741824
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
  pool      = libvirt_pool.ubuntu.name
}

# Create the machine
resource "libvirt_domain" "domain-ubuntu" {
  name   = "ubuntu-terraform"
  memory = "4096"
  vcpu   = 2
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
    volume_id = libvirt_volume.arch-qcow2.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain
