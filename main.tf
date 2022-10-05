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

resource "libvirt_volume" "master-nixos-img" {
  name   = format("master-nixos-img-%s", count.index)
  count  = var.MASTER_COUNT
  pool   = libvirt_pool.nixos.name
  source = "./base-img/nixos.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "worker-nixos-img" {
  name   = format("worker-nixos-img-%s", count.index)
  count  = var.WORKER_COUNT
  pool   = libvirt_pool.nixos.name
  source = "./base-img/nixos.qcow2"
  format = "qcow2"
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = data.template_file.user_data.rendered
  pool      = libvirt_pool.nixos.name
}

resource "libvirt_domain" "masters" {
  count     = var.MASTER_COUNT
  name      = format("master%s", count.index)
  memory    = var.master_config.memory
  vcpu      = var.master_config.vcpus
  cloudinit = libvirt_cloudinit_disk.commoninit.id

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
    volume_id = element(libvirt_volume.master-nixos-img.*.id, count.index)
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
        ssh-keygen -R $ADDRESS < /dev/null
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
        ssh -q -o StrictHostKeyChecking=no root@$ADDRESS exit < /dev/null
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

resource "libvirt_domain" "workers" {
  count     = var.WORKER_COUNT
  name      = format("worker%s", count.index)
  memory    = var.worker_config.memory
  vcpu      = var.worker_config.vcpus
  cloudinit = libvirt_cloudinit_disk.commoninit.id

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
    volume_id = element(libvirt_volume.worker-nixos-img.*.id, count.index)
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
        ssh-keygen -R $ADDRESS < /dev/null
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
        ssh -q -o StrictHostKeyChecking=no root@$ADDRESS exit < /dev/null
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

resource "local_file" "ansible_hosts" {

  depends_on = [
    libvirt_domain.masters,
    libvirt_domain.workers
  ]

  content = templatefile("hosts.tmpl",
    {
      node_map_masters = zipmap(
        tolist(libvirt_domain.masters[*].network_interface[0].addresses[0]), tolist(libvirt_domain.masters.*.name)
      ),
      node_map_workers = zipmap(
        tolist(libvirt_domain.workers[*].network_interface[0].addresses[0]), tolist(libvirt_domain.workers.*.name)
      ),
      "ansible_port" = 22,
      "ansible_user" = "root"
    }
  )
  filename = "hosts"

}

