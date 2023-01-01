# simple-fcos-cluster
A simple kubernetes cluster using fcos, kvm and k0sctl

## Dependencies

- [proxmox-ve](https://www.proxmox.com/en/proxmox-ve)
- [terraform](https://www.terraform.io/)
- [xz](https://en.wikipedia.org/wiki/XZ_Utils)
- [k0sctl](https://github.com/k0sproject/k0sctl)
- [haproxy](http://www.haproxy.org/)

## One-time Configuration

### Create an HA Proxy Server

This is a manual step. I set this up on my Raspberry Pi. You can choose to do the same in a LXC container or a VM.

Make sure that the path to the config is always `/etc/haproxy/haproxy.cfg` and make sure that the service is enabled.

The user whose login you provide needs to own the same file.

```
<!-- This step will change based on your package manager -->
apt-get install haproxy
systemctl enable haproxy
systemctl start haproxy
# Update username here
chown -R username: /etc/haproxy
```

It's a good idea to create a non-root user just to manage haproxy access

```
# Run this from a user with root privileges
sudo EDITOR=vim visudo
%username ALL= (root) NOPASSWD: /bin/systemctl restart haproxy

sudo addgroup username
sudo adduser --disabled-password --ingroup wireproxy username
```


### Create a tfvars file

```
cp terraform.tfvars.example terraform.tfvars
# Edit and save the variables according to your liking
vim terraform.tfvars
```

#### Tips

```
# Get the latest version of k0s
K0S_VERSION=`curl https://api.github.com/repos/k0sproject/k0s/releases/latest -s | jq .name -r`

# Get the latest version of coreos
curl https://builds.coreos.fedoraproject.org/prod/streams/stable/releases.json -s | jq -r --arg name "$1" 'last(.releases[].version)'
```


## Creating the cluster

```
terraform init -upgrade
terraform plan
# WARNING: The next command will override ~/.kube/config. Make a backup if needed.
terraform apply --auto-approve
```

### What does 'terraform apply' do?

- Downloads a version of fcos depending on the tfvars
- Converts the zipped image file to qcow2 and moves it to the proxmox node
- Creates a template using the qcow2 image
- Copies your public key `~/.ssh/id_rsa.pub` to the proxmox node
- Creates ignition files with the system units and ssh keys injected for each VM to be created
- Creates nodes using the ignition configurations and other parameters  specified in `terraform.tfvars`
- Updates the haproxy configuration on a VM/raspberry pi
- Deploys a k0s cluster when the nodes are ready
- Replaces `~/.kube/config` with the new kubeconfig from k0sctl


## Notes

### Debugging HA Proxy

```
haproxy -c -f /etc/haproxy/haproxy.cfg
```

### What about libvirt?

There is a branch named ['kvm'](https://github.com/Naman1997/simple-fcos-cluster/tree/kvm) in the repo that has steps to create a similar cluster using the 'dmacvicar/libvirt' provider. I won't be maintaining that branch - but it can be used as a frame of reference for someone who wants to create a fcos based k8s cluser in their homelab.

### Video

[Link](https://youtu.be/zdAQ3Llj3IU)


## Using HAProxy as a Load Balancer

Since I'm load-balancing ports 80 and 443 as well, we can deploy a nginx controller that uses that IP address for the LoadBalancer!

```
# Update the IP address in the controller yaml
vim ./nginx-example/nginx-controller.yaml
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --values ./nginx-example/nginx-controller.yaml --create-namespace
kubectl create deployment nginx --image=nginx --replicas=5
k expose deploy nginx --port 80
k create -f ./nginx-example/ingress.yaml
curl -k https://192.168.0.101
```

## Exposing your cluster to the internet with a free subdomain!

You'll need an account with duckdns - they provide you with a free subdomain that you can use to host your web services from your home internet.

You'll also be needing a VPS in the cloud that can take in your traffic from a public IP address so that you don't expose your own local IP address.

Oracle provides a [free tier](https://www.oracle.com/in/cloud/free/) account with 4vcpus and 24GB of memory!

For this setup, you'll be installing wireguard on the VPS and your raspberry pi/VM that is running haproxy. The traffic flow is shown in the image below.

![Wireguard_Flow](https://user-images.githubusercontent.com/19908560/210160691-8b00380f-be12-4f13-920a-fb3ef2616f73.jpg)

To expose the traffic properly, follow [this](https://github.com/Naman1997/simple-fcos-cluster/blob/main/Wireguard_Setup.md) guide.

