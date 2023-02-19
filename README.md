# simple-fcos-cluster
[![Terraform](https://github.com/Naman1997/simple-fcos-cluster/actions/workflows/terraform.yml/badge.svg)](https://github.com/Naman1997/simple-fcos-cluster/actions/workflows/terraform.yml)
[![GitHub license](https://img.shields.io/github/license/Naereen/StrapDown.js.svg)](https://github.com/Naman1997/simple-fcos-cluster/blob/main/LICENSE)

A simple kubernetes cluster using Fedora Core OS, Proxmox and k0sctl.

## Dependencies

`Client` refers to the node that will be executing `terraform apply` to create the cluster. The `Raspberry Pi` can be replaced with a VM or a LXC container. The items marked `Optional` are needed only when you want to expose your kubernetes services to the internet via WireGuard.

| Dependency | Location |
| ------ | ------ |
| [Proxmox](https://www.proxmox.com/en/proxmox-ve) | Proxmox node |
| [xz](https://en.wikipedia.org/wiki/XZ_Utils) | Proxmox node & Client |
| [Terraform](https://www.terraform.io/) | Client |
| [k0sctl](https://github.com/k0sproject/k0sctl) | Client |
| [HAproxy](http://www.haproxy.org/) | Raspberry Pi |
| [Wireguard](https://www.wireguard.com/) (Optional) | Raspberry Pi & Cloud VPS |
| [Docker](https://docs.docker.com/) (Optional) | Cloud VPS |

## One-time Configuration

### Make versions.sh executable

A shell script is used to figure out the latest versions of coreos and k0s. This script needs to be executable by the client where you're running `terraform apply`.

```
git clone https://github.com/Naman1997/simple-fcos-cluster.git
cd simple-fcos-cluster/scripts
chmod +x ./versions.sh
```

### Create an HA Proxy Server

I've installed `haproxy` on my Raspberry Pi. You can choose to do the same in a LXC container or a VM.

You need to have passwordless SSH access to a user (from the Client node) in this node which has the permissions to modify the file `/etc/haproxy/haproxy.cfg` and permissions to run `sudo systemctl restart haproxy`. An example is covered in this [doc](https://github.com/Naman1997/simple-fcos-cluster/blob/main/docs/HA_Proxy.md).


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

## Using HAProxy as a Load Balancer for an Ingress

Since HAProxy is load-balancing ports 80 and 443 (of worker nodes), we can deploy nginx-controller such that it uses those ports as an external load balancer IP.

```
# Update the IP address in the controller yaml
vim ./nginx-example/nginx-controller.yaml
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --values ./nginx-example/nginx-controller.yaml --create-namespace
kubectl create deployment nginx --image=nginx --replicas=5
k expose deploy nginx --port 80
# Edit this config to point to your domain
vim ./nginx-example/ingress.yaml.example
mv ./nginx-example/ingress.yaml.example ./nginx-example/ingress.yaml
k create -f ./nginx-example/ingress.yaml
curl -k https://192.168.0.101
```

## Exposing your cluster to the internet with a free subdomain! (Optional)

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
