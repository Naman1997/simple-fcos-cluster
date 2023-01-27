# simple-fcos-cluster
 [![Terraform](https://github.com/Naman1997/simple-fcos-cluster/actions/workflows/terraform.yml/badge.svg)](https://github.com/Naman1997/simple-fcos-cluster/actions/workflows/terraform.yml)
 [![GitHub license](https://img.shields.io/github/license/Naereen/StrapDown.js.svg)](https://github.com/Naman1997/simple-fcos-cluster/blob/main/LICENSE)

A simple kubernetes cluster using Fedora Core OS, Proxmox and k0sctl.
Documentation for exposing the cluster over wireguard is also provided - however this is a manual step at this point.

## Dependencies

| Dependency | Location |
| ------ | ------ |
| [Proxmox](https://www.proxmox.com/en/proxmox-ve) | Proxmox node |
| [Terraform](https://www.terraform.io/) | Client |
| [xz](https://en.wikipedia.org/wiki/XZ_Utils) | Client & Proxmox node |
| [k0sctl](https://github.com/k0sproject/k0sctl) | Client |
| [HAproxy](http://www.haproxy.org/) | Raspberry Pi |
| [Wireguard](https://www.wireguard.com/) (Optional) | Raspberry Pi |

In the table above, 'Client' refers to the computer that will be executing `terraform apply` to create the cluster. The 'Raspberry Pi' can be replaced with a VM or a LXC container.

## Overview

What does 'terraform apply' do?

- Checks if the current dir already contains a file named `coreos.qcow2`.
- If the file is not found, then it downloads the latest version of fcos.
- Converts the zipped image file to a qcow2 file named `coreos.qcow2` and moves it to the Proxmox node.
- Creates a template using the qcow2 image.
- Copies your public key `~/.ssh/id_rsa.pub` to the Proxmox node.
- Creates ignition files with the system units and ssh keys injected for each VM to be created.
- Creates nodes using the ignition configurations and other parameters  specified in `terraform.tfvars`.
- Updates the haproxy configuration on a VM/raspberry pi.
- Deploys a k0s cluster when the nodes are ready. The latest version of k0s is used every time.
- Replaces `~/.kube/config` with the new kubeconfig from k0sctl.

## One-time Configuration

### Make versions.sh executable

I'm using a shell script to figure out the latest versions of coreos and k0s. In order to execute this terraform script, this file needs to be executable by the client where you're running `terraform apply`.

```
git clone https://github.com/Naman1997/simple-fcos-cluster.git
cd simple-fcos-cluster/scripts
chmod +x ./versions.sh
```

### Create an HA Proxy Server

I've installed `haproxy` on my Raspberry Pi. You can choose to do the same in a LXC container or a VM.

It's a good idea to create a non-root user just to manage haproxy access. In this example, the user is named `wireproxy`.

```
# Login to the Raspberry Pi
# Install haproxy
sudo apt-get install haproxy
sudo systemctl enable haproxy
sudo systemctl start haproxy
# Run this from a user with sudo privileges
sudo EDITOR=vim visudo
%wireproxy ALL= (root) NOPASSWD: /bin/systemctl restart haproxy

sudo addgroup wireproxy
sudo adduser --disabled-password --ingroup wireproxy wireproxy
```

You'll need to make sure that you're able to ssh into this user account without a password. For example, let's say the user with sudo privileges is named `ubuntu`. Follow these steps to enable passwordless SSH for `ubuntu`.

```
# Run this from your Client
# Change user/IP address here as needed
ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@192.168.0.100
```

Now you can either follow the same steps for the `wireproxy` user (not recommended as we don't want to give the `wireproxy` user a password) or you can copy the `~/.ssh/authorized_keys` file from the `ubuntu` user to this user.

```
# Login to the Raspberry Pi with user 'ubuntu'
cat ~/.ssh/authorized_keys
# Copy the value in a clipboard
sudo su wireproxy
# You're now logged in as wireproxy user
vim ~/.ssh/authorized_keys
# Paste the same key here
# Logout from the Raspberry Pi
# Make sure you're able to ssh in wireproxy user from your Client
ssh wireproxy@192.168.0.100
```

Using the same example, the user `wireproxy` needs to own the files under `/etc/haproxy`

```
# Login to the Raspberry Pi with user 'ubuntu'
sudo chown -R wireproxy: /etc/haproxy
```


### Create a tfvars file

```
cp terraform.tfvars.example terraform.tfvars
# Edit and save the variables according to your liking
vim terraform.tfvars
```


## Creating the cluster

```
terraform init -upgrade
# Only do this if you don't want to reuse the older coreos image existing in the current dir
# You don't need to run this command if you're using this repo for the 1st time
rm coreos.qcow2
terraform plan
# WARNING: The next command will override ~/.kube/config. Make a backup if needed.
terraform apply --auto-approve
```

## Using HAProxy as a Load Balancer

Since I'm load-balancing ports 80 and 443 as well, we can deploy a nginx controller that uses that IP address for the LoadBalancer!

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

## Exposing your cluster to the internet with a free subdomain!

You'll need an account with duckdns - they provide you with a free subdomain that you can use to host your web services from your home internet.

You'll also be needing a VPS in the cloud that can take in your traffic from a public IP address so that you don't expose your own local IP address.

Oracle provides a [free tier](https://www.oracle.com/in/cloud/free/) account with 4 vcpus and 24GB of memory!

To expose the traffic properly, follow [this](https://github.com/Naman1997/simple-fcos-cluster/blob/main/Wireguard_Setup.md) guide.

For this setup, you'll be installing wireguard on the VPS and your raspberry pi/VM that is running haproxy. The traffic flow is shown in the image below.

![Wireguard_Flow drawio (1) drawio](https://user-images.githubusercontent.com/19908560/210160766-31491844-8ae0-41d9-b31c-7cfe5ee8669a.png)

## Notes

### Debugging HAProxy

```
haproxy -c -f /etc/haproxy/haproxy.cfg
```

### What about libvirt?

There is a branch named ['kvm'](https://github.com/Naman1997/simple-fcos-cluster/tree/kvm) in the repo that has steps to create a similar cluster using the 'dmacvicar/libvirt' provider. I won't be maintaining that branch - but it can be used as a frame of reference for someone who wants to create a Core OS based k8s cluster in their homelab.

### Video

[Link](https://youtu.be/zdAQ3Llj3IU)
