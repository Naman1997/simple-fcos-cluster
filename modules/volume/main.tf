terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.0"
    }
  }
}

resource "libvirt_volume" "volume" {
  name   = var.name
  pool   = "default"
  source = "./base-img/coreos.qcow2"
  format = "qcow2"
}
