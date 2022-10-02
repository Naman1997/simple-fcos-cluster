# How to generate a k8s cluster

## Create the master node

Import the base image generated from the base-img folder into qemu and create a new VM.

SSH into this VM. User is root and there is no password set in the base image.

Generate a new hardware config using `nixos-generate-config`

Remove the existing `/etc/nixos/configuration.nix` and repalce it with the files in this folder.

Update the IP address of the VM in `/etc/nixos/kubernetes.nix` under the variable `kubeMasterIP`.

Rebuild the config using `nixos-rebuild switch` and reboot.

Run the following command to access kubectl binary:

```
mkdir -p .kube && ln -s /etc/kubernetes/cluster-admin.kubeconfig ~/.kube/config
kubectl get nodes
```

