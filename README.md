# simple-fcos-cluster
A simple kubernetes cluster using fcos, kvm and k0sctl

## Dependencies

- [libvirt](https://en.wikipedia.org/wiki/Libvirt)
- [terraform](https://www.terraform.io/)
- [xz](https://en.wikipedia.org/wiki/XZ_Utils)
- [k0sctl](https://github.com/k0sproject/k0sctl)

## One-time Configuration

### Fetch the QEMU base image

Download the [qcow2 image of fcos](https://getfedora.org/en/coreos/download?tab=metal_virtualized&stream=stable&arch=x86_64), decompress it and move the final image to the default location for libvirt images.

You may also need to install [xz](https://en.wikipedia.org/wiki/XZ_Utils) for your linux distribution to decompress the image.

```
# Download the compressed image
wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/VERSION/x86_64/fedora-coreos-VERSION-qemu.x86_64.qcow2.xz -O coreos.qcow2.xz
# Make sure to verify your image using checksum and signature
# Decompress the image using xz
xz -v -d coreos.qcow2.xz
# Move image to default libvirt image location
mv coreos.qcow2 /var/lib/libvirt/images/
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
terraform plan
# WARNING: The next command will override ~/.kube/config. Make a backup if needed.
terraform apply --auto-approve
```

## What does 'terraform apply' do?

- Creates ignition files and adds them to volumes for each worker and master nodes
- Creates nodes with the ignition configurations and other params as specified in the tfvars
- Creates a k0s cluster when the nodes are ready
- Replaces ~/.kube/config with the new kubeconfig from k0sctl
