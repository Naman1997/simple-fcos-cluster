qm destroy 7000 --destroy-unreferenced-disks=1 --purge
sleep 5
qm create 7000 --memory 2048 --net0 virtio,bridge=vmbr0 --agent 1
qm importdisk 7000 /root/fcos-cluster/coreos.qcow2 local-lvm
qm set 7000 --scsihw virtio-scsi-pci --virtio0 local-lvm:vm-7000-disk-0,cache=writeback,discard=on
qm resize 7000 virtio0 +40G
qm set 7000 --boot c --bootdisk virtio0
qm set 7000 --ide2 local-lvm:cloudinit
qm set 7000 --ciuser core --citype nocloud --ipconfig0 ip=dhcp
qm set 7000 --sshkeys '/root/fcos-cluster/id_rsa.pub'
qm set 7000 --name coreos-golden --template 1