terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.0"
    }
    ignition = {
      source = "community-terraform-providers/ignition"
    }
  }
}

data "ignition_user" "core" {
  name                = "core"
  ssh_authorized_keys = [file("~/.ssh/id_rsa.pub")]
}

data "ignition_systemd_unit" "qemu-agent" {
  name    = "qemu-agent.service"
  enabled = true
  content = file("${path.module}/qemu-agent/qemu-agent.service")
}

data "ignition_file" "hostname" {
  path = "/etc/hostname"
  mode = 420 # decimal 0644

  content {
    content = var.name
  }
}


data "ignition_config" "startup" {
  users = [
    data.ignition_user.core.rendered,
  ]

  files = [
    data.ignition_file.hostname.rendered,
  ]

  systemd = [
    "${data.ignition_systemd_unit.qemu-agent.rendered}",
  ]
}

resource "libvirt_ignition" "ignition" {
  name    = var.name
  pool    = "default"
  content = data.ignition_config.startup.rendered
}
