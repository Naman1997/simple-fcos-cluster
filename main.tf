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
  source        = "./modules/domain"
  count         = var.MASTER_COUNT
  name          = format("master%s", count.index)
  memory        = var.master_config.memory
  vcpus         = var.master_config.vcpus
  vol_id        = element(module.master-nixos-img.*.id, count.index)
  pool          = libvirt_pool.nixos.name
  cloud_init_id = libvirt_cloudinit_disk.commoninit.id
}

module "worker_domain" {
  source        = "./modules/domain"
  count         = var.WORKER_COUNT
  name          = format("worker%s", count.index)
  memory        = var.worker_config.memory
  vcpus         = var.worker_config.vcpus
  vol_id        = element(module.worker-nixos-img.*.id, count.index)
  pool          = libvirt_pool.nixos.name
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

# Re-configure the master nodes
# resource "null_resource" "configure_masters" {
#   depends_on = [module.master_domain.node]

#   for_each = {
#     for index, vm in module.worker_domain :
#     vm.name => vm
#   }

#   provisioner "remote-exec" {

#     connection {
#       type = "ssh"
#       user = "root"
#       host = each.value.address
#     }

#     inline = [
#       "sleep2 && nixos-generate-config",
#       "rm /etc/nixos/configuration.nix"
#     ]
#   }

#   provisioner "file" {
#     source      = "./kubernetes/master/kubernetes.nix"
#     destination = "/etc/nixos/kubernetes.nix"
#   }
# }

# Re-configure the worker nodes

# Add all nodes to the cluster
# resource "null_resource" "cluster" {
#   # Changes to any instance of the cluster requires re-provisioning
#   triggers = {
#     cluster_instance_ids = "${join(",", aws_instance.cluster.*.id)}"
#   }

#   # Bootstrap script can run on any instance of the cluster
#   # So we just choose the first in this case
#   connection {
#     host = "${element(aws_instance.cluster.*.public_ip, 0)}"
#   }

#   provisioner "remote-exec" {
#     # Bootstrap script called with private_ip of each node in the cluster
#     inline = [
#       "bootstrap-cluster.sh ${join(" ", aws_instance.cluster.*.private_ip)}",
#     ]
#   }
# }
