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

provider "libvirt" {
  uri = "qemu:///system"
}

module "master-ignition" {
  source = "./modules/ignition"
  name    = format("master-ignition%s", count.index)
  count  = var.MASTER_COUNT
}

module "worker-ignition" {
  source = "./modules/ignition"
  name    = format("worker-ignition%s", count.index)
  count  = var.WORKER_COUNT
}

module "master-coreos-img" {
  source = "./modules/volume"
  name   = format("master-coreos-img-%s", count.index)
  count  = var.MASTER_COUNT
}

module "worker-coreos-img" {
  source = "./modules/volume"
  name   = format("worker-coreos-img-%s", count.index)
  count  = var.WORKER_COUNT
}

module "master_domain" {
  source          = "./modules/domain"
  count           = var.MASTER_COUNT
  name            = format("master%s", count.index)
  memory          = var.master_config.memory
  vcpus           = var.master_config.vcpus
  vol_id          = element(module.master-coreos-img.*.id, count.index)
  coreos_ignition = element(module.master-ignition.*.id, count.index)
}

module "worker_domain" {
  source          = "./modules/domain"
  count           = var.WORKER_COUNT
  name            = format("worker%s", count.index)
  memory          = var.worker_config.memory
  vcpus           = var.worker_config.vcpus
  vol_id          = element(module.worker-coreos-img.*.id, count.index)
  coreos_ignition = element(module.worker-ignition.*.id, count.index)
}

resource "local_file" "k0sctl_config" {

  depends_on = [
    module.master_domain.node,
    module.worker_domain.node
  ]

  content = templatefile("k0s.tmpl",
    {
      node_map_masters = zipmap(
        tolist(module.master_domain.*.address), tolist(module.master_domain.*.name)
      ),
      node_map_workers = zipmap(
        tolist(module.worker_domain.*.address), tolist(module.worker_domain.*.name)
      ),
      "user" = "core"
    }
  )
  filename = "k0sctl.yaml"

  provisioner "local-exec" {
    command = <<-EOT
      k0sctl apply --config k0sctl.yaml
      k0sctl kubeconfig > ~/.kube/config
    EOT
    when = create
  }

}