variable "name" {
  description = "Name of node"
  type        = string
}

variable "memory" {
  description = "Amount of memory needed"
  type        = string
}

variable "vcpus" {
  description = "Number of vcpus"
  type        = number
}

variable "vol_id" {
  description = "Disk volume id"
  type        = string
}

variable "coreos_ignition" {
  description = "Disk identifier for coreos_ignition"
  type        = string
}

variable "autostart" {
  description = "Enable/Disable VM start on host bootup"
  type        = bool
}
