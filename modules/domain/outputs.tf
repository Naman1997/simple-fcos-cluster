output "address" {
  value       = element(flatten(proxmox_virtual_environment_vm.node.ipv4_addresses), 1)
  description = "Non-local IP Address of the node"
}

output "name" {
  value       = proxmox_virtual_environment_vm.node.name
  description = "Name of the node"
}
