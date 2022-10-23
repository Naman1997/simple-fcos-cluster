# Create the master node

## Manual Steps to create a master node

```
docker run -it --rm -e kubeMasterIP=192.168.122.36 -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)":/tmp nixos/nix:latest /bin/sh
export NIXPKGS_ALLOW_INSECURE=1 && nix-env -i nixops
cd /tmp/
./run.sh
mkdir -p .kube && ln -s /etc/kubernetes/cluster-admin.kubeconfig ~/.kube/config
kubectl get nodes
```

## Possible way to create modified images in a VM with nix

```
docker load --input $(nix-build -E 'with import <nixpkgs> {}; pkgs.dockerTools.buildImage { name = "nix-nixops"; contents = [pkgs.nixops pkgs.bash pkgs.findutils pkgs.sedutil pkgs.rPackages.whoami]; config = { Cmd = [ "/bin/bash" ];}; }')
```

The only drawback using this is that this image is not even having basic utilities like ls. This is good in terms of image size, but this makes it hard to work with. Currently get an error saying "cannot figure out user name" using this method.


## Using nixops inside a docker container

```
docker run -it --rm -e kubeMasterIP=192.168.122.36 -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)":/tmp namanarora/docker-nixops:latest bash -c "nixops create -d kubernetes configuration.nix; echo processing; nixops deploy -d kubernetes --force-reboot"
```