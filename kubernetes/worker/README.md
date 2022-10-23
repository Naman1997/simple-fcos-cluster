# Create the master node

## Manual Steps to create a worker node

```
docker run -it --rm -e kubeWorkerIP=192.168.122.36 -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)":/tmp nixos/nix:latest /bin/sh
export NIXPKGS_ALLOW_INSECURE=1 && nix-env -i nixops
cd /tmp/
./run.sh
mkdir -p .kube && ln -s /etc/kubernetes/cluster-admin.kubeconfig ~/.kube/config
kubectl get nodes
```

## Using nixops inside a docker container

```
docker run -it --rm -e kubeWorkerIP=192.168.122.205 -v ~/.ssh/known_hosts:/root/.ssh/known_hosts:ro -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v "$(pwd)":/tmp namanarora/docker-nixops:latest bash -c "nixops create -d kubernetes configuration.nix; echo processing; nixops deploy -d kubernetes --force-reboot"
```