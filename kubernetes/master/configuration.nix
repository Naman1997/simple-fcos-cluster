{
  master = 
    { config, pkgs, ... }:
  let
    kubeMasterIP = "x.x.x.x";
    kubeMasterHostname = "kube-master";
    kubeMasterAPIServerPort = 6443;
  in
  {

    imports =
      [ # Include the results of the hardware scan.
        ./harware-configuration.nix
      ];

      deployment.targetHost = "${kubeMasterIP}";
    # resolve master hostname
    networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";

    # packages for administration tasks
    environment.systemPackages = with pkgs; [
      kompose
      kubectl
      kubernetes
    ];

    services.kubernetes = {
      roles = ["master" "node"];
      masterAddress = kubeMasterHostname;
      apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
      easyCerts = true;
      apiserver = {
        securePort = kubeMasterAPIServerPort;
        advertiseAddress = kubeMasterIP;
      };

      # use coredns
      addons.dns.enable = true;
    };

    # Use the GRUB 2 boot loader.
    boot.loader.grub.enable = true;
    boot.loader.grub.version = 2;
    boot.loader.grub.device = "/dev/vda";

    # Networking
    networking.networkmanager.enable = true;

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      permitRootLogin = "yes";
    };

    system.stateVersion = "22.05";
  };
}