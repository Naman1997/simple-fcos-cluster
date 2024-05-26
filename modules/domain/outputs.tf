output "address" {
  value       = element([for addresses in proxmox_virtual_environment_vm.node.ipv4_addresses : addresses[0] if addresses[0] != "127.0.0.1"], 0)
  description = "Non-local IP Address of the node"
}

output "name" {
  value       = proxmox_virtual_environment_vm.node.name
  description = "Name of the node"
}
