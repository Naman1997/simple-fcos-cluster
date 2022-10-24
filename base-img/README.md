# Download qcow2 image and decompress in this folder

```
wget https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20221001.3.0/x86_64/fedora-coreos-36.20221001.3.0-qemu.x86_64.qcow2.xz -O coreos.qcow2.xz
xz -v -d coreos.qcow2.xz
```