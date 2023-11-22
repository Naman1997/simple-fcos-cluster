output "address" {
  value       = local.non_local_ipv4_address
  description = "Non-local IP Address of the node"
}

output "name" {
  value       = proxmox_virtual_environment_vm.node.name
  description = "Name of the node"
}
