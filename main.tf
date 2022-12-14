terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.11"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.PROXMOX_API_ENDPOINT
  pm_user         = "${var.PROXMOX_USERNAME}@pam"
  pm_password     = var.PROXMOX_PASSWORD
  pm_tls_insecure = true
}

locals {
  iso_url = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${var.fcos_version}/x86_64/fedora-coreos-${var.fcos_version}-qemu.x86_64.qcow2.xz"
}

resource "null_resource" "download_fcos_image" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
      if [[ ! -f ${path.root}/coreos.qcow2 ]]; then
        wget ${local.iso_url} -O coreos.qcow2.xz && rm -f coreos.qcow2 && xz -v -d coreos.qcow2.xz
      fi
    EOF
  }
}

resource "null_resource" "copy_qcow2_image" {
  depends_on = [
    null_resource.download_fcos_image
  ]
  provisioner "remote-exec" {
    connection {
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file("~/.ssh/id_rsa")
    }

    inline = [
      "rm -rf /root/fcos-cluster",
      "mkdir /root/fcos-cluster",
      "rm -rf /root/ignition",
      "mkdir /root/ignition"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/coreos.qcow2"
    destination = "/root/fcos-cluster/coreos.qcow2"
    connection {
      type        = "ssh"
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "null_resource" "copy_ssh_keys" {
  depends_on = [
    null_resource.copy_qcow2_image
  ]
  provisioner "file" {
    source      = "~/.ssh/id_rsa.pub"
    destination = "/root/fcos-cluster/id_rsa.pub"
    connection {
      type        = "ssh"
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "null_resource" "create_template" {
  depends_on = [
    null_resource.copy_ssh_keys
  ]
  provisioner "remote-exec" {
    when = create
    connection {
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file("~/.ssh/id_rsa")
    }

    script = "${path.root}/template.sh"
  }
}

resource "time_sleep" "sleep" {
  depends_on = [
    null_resource.create_template
  ]
  create_duration = "30s"
}

module "master-ignition" {
  depends_on = [
    null_resource.copy_qcow2_image
  ]
  source           = "./modules/ignition"
  name             = format("master%s", count.index)
  proxmox_user     = var.PROXMOX_USERNAME
  proxmox_password = var.PROXMOX_PASSWORD
  proxmox_host     = var.PROXMOX_IP
  count            = var.MASTER_COUNT
}

module "worker-ignition" {
  depends_on = [
    null_resource.copy_qcow2_image
  ]
  source           = "./modules/ignition"
  name             = format("worker%s", count.index)
  proxmox_user     = var.PROXMOX_USERNAME
  proxmox_password = var.PROXMOX_PASSWORD
  proxmox_host     = var.PROXMOX_IP
  count            = var.WORKER_COUNT
}

module "master_domain" {

  depends_on = [
    time_sleep.sleep
  ]

  source         = "./modules/domain"
  count          = var.MASTER_COUNT
  name           = format("master%s", count.index)
  memory         = var.master_config.memory
  vcpus          = var.master_config.vcpus
  sockets        = var.master_config.sockets
  autostart      = var.autostart
  default_bridge = var.DEFAULT_BRIDGE
  target_node    = var.TARGET_NODE
}

module "worker_domain" {

  depends_on = [
    time_sleep.sleep
  ]

  source         = "./modules/domain"
  count          = var.WORKER_COUNT
  name           = format("worker%s", count.index)
  memory         = var.worker_config.memory
  vcpus          = var.worker_config.vcpus
  sockets        = var.worker_config.sockets
  autostart      = var.autostart
  default_bridge = var.DEFAULT_BRIDGE
  target_node    = var.TARGET_NODE
}


resource "local_file" "haproxy_config" {

  depends_on = [
    module.master_domain.node,
    module.worker_domain.node
  ]

  content = templatefile("haproxy.tmpl",
    {
      node_map_masters = zipmap(
        tolist(module.master_domain.*.address), tolist(module.master_domain.*.name)
      ),
      node_map_workers = zipmap(
        tolist(module.worker_domain.*.address), tolist(module.worker_domain.*.name)
      )
    }
  )
  filename = "haproxy.cfg"

  provisioner "file" {
    source      = "${path.root}/haproxy.cfg"
    destination = "/etc/haproxy/haproxy.cfg"
    connection {
      type        = "ssh"
      host        = var.ha_proxy_server
      user        = var.ha_proxy_user
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = var.ha_proxy_server
      user        = var.ha_proxy_user
      private_key = file("~/.ssh/id_rsa")
    }

    inline = [
      "sudo systemctl restart haproxy"
    ]
  }
}

resource "local_file" "k0sctl_config" {

  depends_on = [
    local_file.haproxy_config
  ]

  content = templatefile("k0s.tmpl",
    {
      node_map_masters = zipmap(
        tolist(module.master_domain.*.address), tolist(module.master_domain.*.name)
      ),
      node_map_workers = zipmap(
        tolist(module.worker_domain.*.address), tolist(module.worker_domain.*.name)
      ),
      "user"        = "core",
      "k0s_version" = var.k0s_version,
      "ha_proxy_server" : var.ha_proxy_server
    }
  )
  filename = "k0sctl.yaml"

  provisioner "local-exec" {
    command = <<-EOT
      k0sctl apply --config k0sctl.yaml
      k0sctl kubeconfig > ~/.kube/config
    EOT
    when    = create
  }
}