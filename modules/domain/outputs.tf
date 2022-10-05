output "address" {
  value       = libvirt_domain.node.network_interface[0].addresses[0]
  description = "IP Address of the node"
}

output "name" {
  value       = libvirt_domain.node.name
  description = "Name of the node"
}
