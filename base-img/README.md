# How to create a nix-os base qcow2 image

## Creating the qcow2 image using docker

```
sudo docker run -v "$(pwd)":/tmp nixos/nix:2.11.1 /bin/sh -c 'echo "system-features = kvm" > /etc/nix/nix.conf && nix-build "<nixpkgs/nixos>" -A config.system.build.qcow2 --arg configuration "{ imports = [ ./tmp/build-qcow2.nix ]; }" && mv ./result/nixos.qcow2 /tmp/nixos.qcow2' && sudo chmod +rw nixos.qcow2
```

## Using another VM or your own host

You need the nix-build binary to generate this qcow2 image. In order to do that, you can either create a new VM or you can install the nix binary on your host system.

Clone this repo on the VM or your local. `cd` into this dir and build the base qcow2 image using the command:

```
nix-build '<nixpkgs/nixos>' -A config.system.build.qcow2 --arg configuration "{ imports = [ ./build-qcow2.nix ]; }"
```

If you used a VM, copy the image to your local using scp
```
scp root@<VM_IP>:/path/to/nixos.qcow2 /path/to/paste/
```

References:

- https://gist.github.com/tarnacious/f9674436fff0efeb4bb6585c79a3b9ff