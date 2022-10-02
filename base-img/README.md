# How to create a nix-os base qcow2 image

You need the nix-build binary to generate this qcow2 image. In order to do that, you can either create a new VM or you can install the nix binary on your host system. I would recommend doing this on a temporary VM.

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