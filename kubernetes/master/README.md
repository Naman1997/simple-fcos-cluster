# Create the master node

Import the base image generated from the base-img folder into qemu and create a new VM.

SSH into this VM. User is root and there is no password set in the base image.

Generate a new hardware config using `nixos-generate-config` on the VM and copy the hardware config of any master node to this dir

Create a docker container with the current dir added as a volume mount. The container should have nix-env.

Add the ssh key-pair using `ssh-add`

`nix-env -i nixops` [Need to check if there is a way to create a container with this preinstalled. This also seems to ask for a password, need to see if it can take in ssh keys as an input param - probably that can be sent as a file in this dir]

`nixops create -d kubernetes configuration.nix`

`nixops deploy -d kubernetes --force-reboot`

Run the following command to configure kubectl:

```
mkdir -p .kube && ln -s /etc/kubernetes/cluster-admin.kubeconfig ~/.kube/config
kubectl get nodes
```
