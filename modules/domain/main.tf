terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.43.2"
    }
  }
}

resource "proxmox_virtual_environment_vm" "node" {
  name                = var.name
  on_boot             = var.autostart
  node_name           = var.target_node
  scsi_hardware       = "virtio-scsi-pci"
  kvm_arguments       = "-fw_cfg name=opt/com.coreos/config,file=/root/ignition/ignition_${var.name}.ign"
  timeout_shutdown_vm = 300
  reboot              = true

  memory {
    dedicated = var.memory
    floating  = var.memory
  }

  cpu {
    cores   = var.vcpus
    type    = "host"
    sockets = var.sockets
  }

  agent {
    enabled = true
    timeout = "10s"
  }

  clone {
    retries = 3
    vm_id   = 7000
    full    = true
  }

  network_device {
    model  = "e1000"
    bridge = var.default_bridge
  }

  provisioner "local-exec" {
    command = <<-EOT
      n=0
      until [ "$n" -ge 10 ]
      do
        echo "Attempt number: $n"
        ssh-keygen -R $ADDRESS
        if [ $? -eq 0 ]; then
          echo "Successfully removed $ADDRESS"
          break
        fi
        n=$((n+1)) 
        sleep $[ ( $RANDOM % 10 )  + 1 ]s
      done
    EOT
    environment = {
      ADDRESS = element([for addresses in self.ipv4_addresses : addresses[0] if addresses[0] != "127.0.0.1"], 0)
    }
    when = destroy
  }

  provisioner "local-exec" {
    command = <<-EOT
      n=0
      until [ "$n" -ge 10 ]
      do
        echo "Attempt number: $n"
        ssh-keyscan -H $ADDRESS >> ~/.ssh/known_hosts
        ssh -q -o StrictHostKeyChecking=no core@$ADDRESS exit < /dev/null
        if [ $? -eq 0 ]; then
          echo "Successfully added $ADDRESS"
          break
        fi
        n=$((n+1)) 
        sleep $[ ( $RANDOM % 10 )  + 1 ]s
      done
    EOT
    environment = {
      ADDRESS = element([for addresses in self.ipv4_addresses : addresses[0] if addresses[0] != "127.0.0.1"], 0)
    }
    when = create
  }
}

locals {
  non_local_ipv4_address = element([for addresses in proxmox_virtual_environment_vm.node.ipv4_addresses : addresses[0] if addresses[0] != "127.0.0.1"], 0)
}

resource "null_resource" "wait_for_ssh" {
  depends_on = [
    proxmox_virtual_environment_vm.node
  ]
  provisioner "remote-exec" {
    connection {
      host        = local.non_local_ipv4_address
      user        = "core"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "5m"
    }

    inline = [
      "# Connected!",
      "echo Connected to `hostname`"
    ]
  }
}
