terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.6.14"
    }
  }
}

resource "libvirt_volume" "volume" {
  name   = var.name
  pool   = var.pool
  source = "./base-img/nixos.qcow2"
  format = "qcow2"
}
