terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.0"
    }
  }
}

resource "libvirt_domain" "node" {
  name            = var.name
  memory          = var.memory
  vcpu            = var.vcpus
  coreos_ignition = var.coreos_ignition
  qemu_agent      = true

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
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
    volume_id = var.vol_id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
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
      ADDRESS = self.network_interface[0].addresses[0]
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
      ADDRESS = self.network_interface[0].addresses[0]
    }
    when = create
  }
}
