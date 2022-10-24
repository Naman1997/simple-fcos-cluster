output "output_log" {
  depends_on = [
    local_file.k0sctl_config
  ]
  value = "Run 'kubectl get nodes' to see node status."
}
