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

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = data.template_file.user_data.rendered
  pool      = libvirt_pool.nixos.name
}

module "master-nixos-img" {
  source = "./modules/volume"
  name   = format("master-nixos-img-%s", count.index)
  count  = var.MASTER_COUNT
  pool   = libvirt_pool.nixos.name
}

module "worker-nixos-img" {
  source = "./modules/volume"
  name   = format("worker-nixos-img-%s", count.index)
  count  = var.WORKER_COUNT
  pool   = libvirt_pool.nixos.name
}

module "master_domain" {
  source = "./modules/domain"
  count  = var.MASTER_COUNT
  name   = format("master%s", count.index)
  memory = var.master_config.memory
  vcpus  = var.master_config.vcpus
  vol_id = element(module.master-nixos-img.*.id, count.index)
  pool   = libvirt_pool.nixos.name
  cloud_init_id = libvirt_cloudinit_disk.commoninit.id
}

module "worker_domain" {
  source = "./modules/domain"
  count  = var.WORKER_COUNT
  name   = format("worker%s", count.index)
  memory = var.worker_config.memory
  vcpus  = var.worker_config.vcpus
  vol_id = element(module.worker-nixos-img.*.id, count.index)
  pool   = libvirt_pool.nixos.name
  cloud_init_id = libvirt_cloudinit_disk.commoninit.id
}

resource "local_file" "ansible_hosts" {

  depends_on = [
    module.master_domain.node,
    module.worker_domain.node
  ]

  content = templatefile("hosts.tmpl",
    {
      node_map_masters = zipmap(
        tolist(module.master_domain.*.address), tolist(module.master_domain.*.name)
      ),
      node_map_workers = zipmap(
        tolist(module.worker_domain.*.address), tolist(module.worker_domain.*.name)
      ),
      "ansible_port" = 22,
      "ansible_user" = "root"
    }
  )
  filename = "hosts"

}

