{ config, ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/logging.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/wireguard-site.nix
    ../../modules/networking/vlans.nix
    ../../modules/observability/exporters.nix
    ../../modules/services/frigate.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "mom-edge";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;
  personalInfra.common.logging.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  networking.interfaces.ens18.ipv4.addresses = [
    {
      address = "10.10.10.2";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "10.10.10.1";
  networking.nameservers = [
    "1.1.1.1"
    "9.9.9.9"
  ];

  sops = {
    defaultSopsFile = ./secrets.enc.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets."wireguard/site-private-key" = { };
  };

  personalInfra.networking.wireguardSite = {
    enable = true;
    interfaceName = "wg-mom";
    address = "10.8.0.30/32";
    privateKeyFile = config.sops.secrets."wireguard/site-private-key".path;
    routedSubnets = [ "10.10.10.0/24" ];
    peers = [
      {
        # Placeholder public key. Replace with the real VPS WireGuard public key
        # before activating the Mom tunnel.
        publicKey = "cLA9Yj3kROI3AzssiuLUT1USXgg5NhInCdqXQ9xiOCE=";
        endpoint = "theau-vps.duckdns.org:51820";
        allowedIPs = [
          "10.8.0.0/24"
          "10.1.0.0/16"
          "10.224.0.0/16"
        ];
        persistentKeepalive = 25;
      }
    ];
  };

  personalInfra.networking.vlans.enable = false;
  personalInfra.observability.exporters = {
    enable = true;
    nodeExporter = true;
    blackboxExporter = true;
    listenAddress = "10.8.0.30";
  };
  personalInfra.services.frigate.enable = false;

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      9100
      9115
    ];
  };

  boot.growPartition = true;
  boot.loader.grub.device = "/dev/vda";

  # TODO: replace with the real Proxmox VM disk identifier if installed on
  # bare metal instead of a VM.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.stateVersion = "25.05";
}
