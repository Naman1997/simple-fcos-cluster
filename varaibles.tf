#Variables
variable "master_config" {
  description = "kmaster config"
  type = object({
    memory = string
    vcpus  = number
  })
  default = {
    memory = "2048"
    vcpus  = 1
  }
}

variable "worker_config" {
  description = "kworker config"
  type = object({
    memory = string
    vcpus  = number
  })
  default = {
    memory = "2048"
    vcpus  = 1
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