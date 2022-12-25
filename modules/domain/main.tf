terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.6"
    }
  }
}

resource "proxmox_vm_qemu" "node" {
  name        = var.name
  memory      = var.memory
  cores       = var.vcpus
  sockets     = var.sockets
  onboot      = var.autostart
  target_node = var.target_node
  agent       = 1
  clone       = "coreos-golden"
  full_clone  = true
  boot        = "order=scsi0;net0"
  args        = "-fw_cfg name=opt/com.coreos/config,file=/tmp/ignition_${var.name}.ign"

  network {
    model  = "e1000"
    bridge = var.default_bridge
  }

  provisioner "local-exec" {
    command = <<-EOT
      n=0
      until [ "$n" -ge 5 ]
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
      ADDRESS = self.ssh_host
    }
    when = destroy
  }

  provisioner "local-exec" {
    command = <<-EOT
      n=0
      until [ "$n" -ge 5 ]
      do
        echo "Attempt number: $n"
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
      ADDRESS = self.ssh_host
    }
    when = create
  }
}