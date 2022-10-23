# Create the master node

## Manual Steps to create a cluster with just the master node

```
docker run -it --rm -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)":/tmp nixos/nix:latest /bin/sh
export NIXPKGS_ALLOW_INSECURE=1 && nix-env -i nixops
cd /tmp/
# Edit configuration.nix with the correct kubeMasterIP
./run.sh
mkdir -p .kube && ln -s /etc/kubernetes/cluster-admin.kubeconfig ~/.kube/config
kubectl get nodes
```

## Possible way to create modified images in a VM with nix

```
docker load --input $(nix-build -E 'with import <nixpkgs> {}; pkgs.dockerTools.buildImage { name = "nix-nixops"; contents = pkgs.nixops; config = { Cmd = [ "/bin/nixops" ];}; }')
```

The only drawback using this is that this image is not even having basic utilities like ls. This is good in terms of image size, but this makes it hard to work with.

```
docker run -it --rm -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)":/tmp namanarora/nix-nixops:latest /bin/bash -c "nixops create -d kubernetes configuration.nix; echo processing; nixops deploy -d kubernetes --force-reboot"
```