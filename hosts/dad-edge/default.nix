{ config, ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/logging.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/wireguard-site.nix
    ../../modules/observability/exporters.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "dad-edge";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;
  personalInfra.common.logging.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.7.10.2";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = "10.7.10.1";
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
    interfaceName = "wg-dad";
    address = "10.8.0.40/32";
    privateKeyFile = config.sops.secrets."wireguard/site-private-key".path;
    routedSubnets = [ "10.7.10.0/24" ];
    peers = [
      {
        # Placeholder public key. Replace with the real VPS WireGuard public key
        # before activating the Dad tunnel.
        publicKey = "oIyPH6kmqTqzKVgu44Rq6AslgjXIQqMY6jIAtGt5HUQ=";
        endpoint = "theau-vps.duckdns.org:51820";
        allowedIPs = [
          "10.8.0.0/24"
          "10.1.0.0/16"
          "10.224.0.0/16"
          "10.10.10.0/24"
        ];
        persistentKeepalive = 25;
      }
    ];
  };

  personalInfra.observability.exporters = {
    enable = true;
    nodeExporter = true;
    blackboxExporter = false;
    listenAddress = "10.8.0.40";
  };

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      9100
    ];
  };

  boot.growPartition = true;
  boot.loader.grub.device = "/dev/vda";

  # TODO: replace with the real device identifier for the chosen small edge
  # hardware. This default keeps the target buildable as a generic VM image.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.stateVersion = "25.05";
}
