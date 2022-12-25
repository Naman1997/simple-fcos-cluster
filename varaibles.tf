#Variables
variable "master_config" {
  description = "kmaster config"
  type = object({
    memory  = string
    vcpus   = number
    sockets = number
  })
  default = {
    memory  = "4096"
    vcpus   = 2
    sockets = 1
  }
}

variable "worker_config" {
  description = "kworker config"
  type = object({
    memory  = string
    vcpus   = number
    sockets = number
  })
  default = {
    memory  = "4096"
    vcpus   = 2
    sockets = 1
  }
}

variable "MASTER_COUNT" {
  description = "Number of masters to create"
  type        = number
  validation {
    condition     = var.MASTER_COUNT % 2 == 1
    error_message = "Number of master nodes must be always odd. Learn more here: https://discuss.kubernetes.io/t/high-availability-host-numbers/13143/2"
  }
  validation {
    condition     = var.MASTER_COUNT != 0
    error_message = "Number of master nodes cannot be 0"
  }
  default = 1
}

variable "WORKER_COUNT" {
  description = "Number of workers to create"
  type        = number
  default     = 1
}

variable "autostart" {
  description = "Enable/Disable VM start on host bootup"
  type        = bool
  default     = false
}

variable "PROXMOX_API_ENDPOINT" {
  description = "API endpoint for proxmox"
  type        = string
}

variable "PROXMOX_USERNAME" {
  description = "User name used to login proxmox"
  type        = string
}

variable "PROXMOX_PASSWORD" {
  description = "Password used to login proxmox"
  type        = string
}

variable "PROXMOX_IP" {
  description = "IP address for proxmox"
  type        = string
}

variable "DEFAULT_BRIDGE" {
  description = "Bridge to use when creating VMs in proxmox"
  type        = string
}

variable "TARGET_NODE" {
  description = "Target node name in proxmox"
  type        = string
}

variable "fcos_version" {
  type = string
}

variable "k0s_version" {
  type = string
}

variable "ha_proxy_server" {
  type = string
}

variable "ha_proxy_user" {
  type = string
}