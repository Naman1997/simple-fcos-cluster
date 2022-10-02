variable "username" {
  type = string
}

source "qemu" "archlinux" {
  accelerator           = "kvm"
  disk_image            = true
  disk_interface        = "virtio"
  format                = "qcow2"
  http_directory        = "./http"
  iso_checksum          = "file:https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2.SHA256"
  iso_url               = "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
  net_device            = "virtio-net"
  shutdown_command      = "sudo systemctl poweroff"
  ssh_password          = "archPassword"
  ssh_timeout           = "20m"
  ssh_username          = "${var.username}"
  vm_name               = "golden-arch.qcow2"
  cd_files              = ["cloud-init/meta-data", "cloud-init/user-data"]
  cd_label              = "cidata"
  boot_wait             = "30s"
  boot_command          = [
      "${var.username}<enter>arch<enter>",
      "arch<enter>archPassword<enter>archPassword<enter><wait>",
      "curl -sfSLO http://{{ .HTTPIP }}:{{ .HTTPPort }}/pkglist.txt<enter><wait>"
    ]
}

build {
  sources = ["source.qemu.archlinux"]

  provisioner "shell" {
    inline = ["sudo pacman -Sy ansible --noconfirm"]
  }

  provisioner "ansible-local" {
    playbook_file = "./playbook.yml"
    extra_arguments = ["--extra-vars", "'username=${var.username}'"]
  }

  provisioner "shell" {
    inline = ["sudo usermod -p '!' ${var.username}"]
  }
}