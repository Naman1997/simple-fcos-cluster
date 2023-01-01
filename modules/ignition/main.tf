terraform {
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.9"
    }
  }
}

# Butane config
data "template_file" "config" {
  template = file("${path.module}/system-units/template.yaml")
  vars = {
    domain_name        = var.name
    ssh_authorized_key = file("~/.ssh/id_rsa.pub")
  }
}

# Worker config converted to Ignition
data "ct_config" "ignition" {
  content = data.template_file.config.*.rendered[0]
  strict  = true
}

# Send Ignition file to Proxmox server
resource "null_resource" "proxmox_configs" {

  connection {
    type     = "ssh"
    user     = var.proxmox_user
    password = var.proxmox_password
    host     = var.proxmox_host
  }

  provisioner "file" {
    content     = data.ct_config.ignition.*.rendered[0]
    destination = "/root/ignition/ignition_${var.name}.ign"
  }
}