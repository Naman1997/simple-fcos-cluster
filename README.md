# simple-fcos-cluster
[![Terraform](https://github.com/Naman1997/simple-fcos-cluster/actions/workflows/terraform.yml/badge.svg)](https://github.com/Naman1997/simple-fcos-cluster/actions/workflows/terraform.yml)
[![GitHub license](https://img.shields.io/github/license/Naereen/StrapDown.js.svg)](https://github.com/Naman1997/simple-fcos-cluster/blob/main/LICENSE)

A simple kubernetes cluster using Fedora Core OS, Proxmox and k0sctl.

## Dependencies

`Client` refers to the node that will be executing `terraform apply` to create the cluster.

| Dependency | Location |
| ------ | ------ |
| [Proxmox](https://www.proxmox.com/en/proxmox-ve) | Proxmox node |
| [xz](https://en.wikipedia.org/wiki/XZ_Utils) | Proxmox node & Client |
| [jq](https://stedolan.github.io/jq/) | Client |
| [Terraform](https://www.terraform.io/) | Client |
| [k0sctl](https://github.com/k0sproject/k0sctl) | Client |


### Create the terraform.tfvars file

The variables needed to configure this script are documented in this [doc](https://github.com/Naman1997/simple-fcos-cluster/blob/main/docs/Variables.md).

```
cp terraform.tfvars.example terraform.tfvars
# Edit and save the variables according to your liking
vim terraform.tfvars
```

## Enable the Snippets feature in Proxmox

In the proxmox web portal, go to `Datacenter` > `Storage` > Click on `local` > `Edit` > Under `Content` choose `Snippets` > Click on `OK` to save.

![local directory](image.png)

## Creating the cluster

```
terraform init -upgrade
# You don't need to run the next command if you're using this repo for the 1st time
# Only do this if you don't want to reuse the older coreos image existing in the current dir
rm coreos.qcow2
terraform plan
# WARNING: The next command will override ~/.kube/config. Make a backup if needed.
terraform apply --auto-approve
```

The created VMs will reboot twice before `qemu-guest-agent` is able to detect their IP addresses. This can take anywhere from 2-5 mins depending on your hardware.

## Expose your cluster to the internet using an Ingress (Optional)

It is possible to expose your cluster to the internet over a small vps even if both your vps and your public ips are dynamic. This is possible by setting up dynamic dns for both your internal network and the vps using something like duckdns
and a docker container to regularly monitor the IP addresses on both ends. A connection can be then made using wireguard to traverse the network between these 2 nodes. This way you can hide your public IP while exposing services to the internet.

Project Link: [wireguard-k8s-lb](https://github.com/Naman1997/wireguard-k8s-lb) (This is one possible implementation)

### Poweroff all VMs in the cluster

```
ansible-playbook -i hosts poweroff.yaml
```

### Debugging HAProxy

```
haproxy -c -f /etc/haproxy/haproxy.cfg
```

### What about libvirt?

There is a branch named ['kvm'](https://github.com/Naman1997/simple-fcos-cluster/tree/kvm) in the repo that has steps to create a similar cluster using the 'dmacvicar/libvirt' provider. I won't be maintaining that branch - but it can be used as a frame of reference for someone who wants to create a Core OS based k8s cluster in their homelab.

### Video

[Link](https://youtu.be/zdAQ3Llj3IU)
