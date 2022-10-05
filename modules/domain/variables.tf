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

variable "pool" {
  description = "Pool name"
  type        = string
}

variable "cloud_init_id" {
  description = "Disk identifier for cloud_init"
  type        = string
}
