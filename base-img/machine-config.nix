{ pkgs, lib, ... }:

with lib;

{
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  config = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot.growPartition = true;
    boot.kernelParams = [ "console=ttyS0" ];
    boot.loader.grub.device = "/dev/vda";
    boot.loader.timeout = 0;

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      permitRootLogin = "yes";
    };

    # Enable the guest agent
    services.qemuGuest.enable = true;

    # Enable cloud-init
    services.cloud-init.enable = true;

  };
}