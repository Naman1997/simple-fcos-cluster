variable "name" {
  description = "Name of ignition volume"
  type        = string
}

variable "proxmox_host" {
  description = "IP address for proxmox"
  type        = string
}

variable "proxmox_user" {
  description = "User name used to login proxmox"
  type        = string
}

variable "proxmox_password" {
  description = "Password used to login proxmox"
  type        = string
}