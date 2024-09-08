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

## One-time Configuration

### Make versions.sh executable

A shell script is used to figure out the latest versions of coreos and k0s. This script needs to be executable by the client where you're running `terraform apply`.

```
git clone https://github.com/Naman1997/simple-fcos-cluster.git
cd simple-fcos-cluster/scripts
chmod +x ./versions.sh
```


### Create the terraform.tfvars file

The variables needed to configure this script are documented in this [doc](https://github.com/Naman1997/simple-fcos-cluster/blob/main/docs/Variables.md).

```
cp terraform.tfvars.example terraform.tfvars
# Edit and save the variables according to your liking
vim terraform.tfvars
```


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

## Expose your cluster to the internet using an Ingress (Optional)

It is possible to expose your cluster to the internet over a small vps even if both your vps and your public ips are dynamic. This is possible by setting up dynamic dns for both your internal network and the vps using something like duckdns
and a docker container to regularly monitor the IP addresses on both ends. A connection can be then made using wireguard to traverse the network between these 2 nodes. This way you can hide your public IP while exposing services to the internet.

Project Link: [wireguard-k8s-lb](https://github.com/Naman1997/wireguard-k8s-lb) (This is one possible implementation)

### How to do this manually?

You'll need an account with duckdns - they provide you with a free subdomain that you can use to host your web services from your home internet. You'll also be needing a VPS in the cloud that can take in your traffic from a public IP address so that you don't expose your own IP address. Oracle provides a [free tier](https://www.oracle.com/in/cloud/free/) account with 4 vcpus and 24GB of memory. I'll be using this to create a VM. To expose the traffic properly, follow this [guide](https://github.com/Naman1997/simple-fcos-cluster/blob/main/docs/Wireguard_Setup.md).

For this setup, we'll be installing wireguard on the VPS and the node that is running haproxy. The traffic flow is shown in the image below.

![Wireguard_Flow drawio (1) drawio](https://user-images.githubusercontent.com/19908560/210160766-31491844-8ae0-41d9-b31c-7cfe5ee8669a.png)

## Notes

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
