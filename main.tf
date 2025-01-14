terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.69.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.PROXMOX_API_ENDPOINT
  username = "${var.PROXMOX_USERNAME}@pam"
  password = var.PROXMOX_PASSWORD
  insecure = true
}

data "external" "versions" {
  program = [
    "${path.module}/scripts/versions.sh",
  ]
}

locals {
  ha_proxy_user = "ubuntu"
  fcos_version  = data.external.versions.result["fcos_version"]
  k0s_version   = data.external.versions.result["k0s_version"]
  iso_url       = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${local.fcos_version}/x86_64/fedora-coreos-${local.fcos_version}-qemu.x86_64.qcow2.xz"
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
      private_key = file(var.PROXMOX_SSH_KEY)
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
      private_key = file(var.PROXMOX_SSH_KEY)
    }
  }
}

resource "null_resource" "copy_ssh_keys" {
  depends_on = [
    null_resource.copy_qcow2_image
  ]
  provisioner "file" {
    source      = join("", [var.PROXMOX_SSH_KEY, ".pub"])
    destination = "/root/fcos-cluster/id_rsa.pub"
    connection {
      type        = "ssh"
      host        = var.PROXMOX_IP
      user        = var.PROXMOX_USERNAME
      private_key = file(var.PROXMOX_SSH_KEY)
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
      private_key = file(var.PROXMOX_SSH_KEY)
    }

    script = "${path.root}/scripts/template.sh"
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
  ssh_key          = join("", [var.PROXMOX_SSH_KEY, ".pub"])
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
  ssh_key          = join("", [var.PROXMOX_SSH_KEY, ".pub"])
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

module "proxy" {
  source         = "./modules/proxy"
  ha_proxy_user  = local.ha_proxy_user
  DEFAULT_BRIDGE = var.DEFAULT_BRIDGE
  TARGET_NODE    = var.TARGET_NODE
  ssh_key        = join("", [var.PROXMOX_SSH_KEY, ".pub"])
}


resource "local_file" "haproxy_config" {

  depends_on = [
    module.master_domain.node,
    module.worker_domain.node,
    module.proxy.node
  ]

  content = templatefile("${path.root}/templates/haproxy.tmpl",
    {
      node_map_masters = zipmap(
        module.master_domain.*.address, module.master_domain.*.name
      ),
      node_map_workers = zipmap(
        module.worker_domain.*.address, module.worker_domain.*.name
      )
    }
  )
  filename = "haproxy.cfg"

  provisioner "file" {
    source      = "${path.root}/haproxy.cfg"
    destination = "/etc/haproxy/haproxy.cfg"
    connection {
      type        = "ssh"
      host        = module.proxy.proxy_ipv4_address
      user        = local.ha_proxy_user
      private_key = file(var.PROXMOX_SSH_KEY)
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = module.proxy.proxy_ipv4_address
      user        = local.ha_proxy_user
      private_key = file(var.PROXMOX_SSH_KEY)
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

  content = templatefile("${path.root}/templates/k0s.tmpl",
    {
      node_map_masters = zipmap(
        tolist(module.master_domain.*.address), tolist(module.master_domain.*.name)
      ),
      node_map_workers = zipmap(
        tolist(module.worker_domain.*.address), tolist(module.worker_domain.*.name)
      ),
      "user"            = "core",
      "k0s_version"     = local.k0s_version,
      "ha_proxy_server" = module.proxy.proxy_ipv4_address,
      "ssh_key"         = var.PROXMOX_SSH_KEY
    }
  )
  filename = "k0sctl.yaml"
}

resource "null_resource" "setup_cluster" {

  depends_on = [
    local_file.k0sctl_config
  ]

  provisioner "local-exec" {
    command = <<-EOT
      MAX_RETRIES=5
      RETRY_INTERVAL=10
      for ((i = 1; i <= MAX_RETRIES; i++)); do
        k0sctl apply --config k0sctl.yaml
        code=$?
        if [ $code -eq 0 ]; then
          break
        fi
        if [ $i -lt $MAX_RETRIES ]; then
          echo "Unable to apply config. Retrying in 10 seconds..."
          sleep $RETRY_INTERVAL
        else
          echo "Maximum retries reached. Unable to apply config."
          exit 1
        fi
      done
      mkdir -p ~/.kube
      k0sctl kubeconfig > ~/.kube/config
      chmod 600 ~/.kube/config
    EOT
    when    = create
  }

}

resource "local_file" "ansible_hosts" {

  depends_on = [
    local_file.haproxy_config
  ]

  content = templatefile("${path.root}/templates/ansible.tmpl",
    {
      node_map_masters = zipmap(
        tolist(module.master_domain.*.address), tolist(module.master_domain.*.name)
      ),
      node_map_workers = zipmap(
        tolist(module.worker_domain.*.address), tolist(module.worker_domain.*.name)
      ),
      "ansible_port" = 22,
      "ansible_user" = "core"
    }
  )
  filename = "hosts"

}