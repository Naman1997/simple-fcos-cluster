# simple-fcos-cluster
A simple kubernetes cluster using fcos, kvm and k0sctl

## Dependencies

- [proxmox-ve](https://www.proxmox.com/en/proxmox-ve)
- [terraform](https://www.terraform.io/)
- [xz](https://en.wikipedia.org/wiki/XZ_Utils)
- [k0sctl](https://github.com/k0sproject/k0sctl)
- [haproxy](http://www.haproxy.org/)

## One-time Configuration

### Create a tfvars file

```
cp terraform.tfvars.example terraform.tfvars
# Edit and save the variables according to your liking
vim terraform.tfvars
```

## Creating the cluster

```
terraform init -upgrade
terraform plan
# WARNING: The next command will override ~/.kube/config. Make a backup if needed.
terraform apply --auto-approve
```

## What does 'terraform apply' do?

- Downloads a version of fcos depending on the tfvars
- Converts the zipped file to qcow2 and moves it to proxmox node
- Creates a template using the qcow2 image
- Creates ignition files for each VM
- Creates nodes with the ignition configurations and other params as specified in the tfvars
- [MANUAL INTERVENTION NEEDED HERE] You need to update the IP addresses in your haproxy while the cluster is being brought up
- Creates a k0s cluster when the nodes are ready
- Replaces ~/.kube/config with the new kubeconfig from k0sctl


## TODO

- Automate configuration of the HA proxy server