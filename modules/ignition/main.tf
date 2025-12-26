terraform {
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = " 0.14.0"
    }
  }
}

# Worker config converted to Ignition
data "ct_config" "ignition" {
  content = templatefile(
    "${path.module}/system-units/template.yaml",
    {
      domain_name        = var.name,
      ssh_authorized_key = file(pathexpand(var.ssh_key))
    }
  )
  strict = true
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