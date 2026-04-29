{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/services/prowlarr.nix
    ../../modules/services/seedbox.nix
    ../../modules/observability/exporters.nix
    ../../modules/backup/restic.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "seedbox-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      8080
    ];
  };

  personalInfra.services.seedbox = {
    enable = true;
    dataRoot = "/srv/seedbox";
    gluetun = {
      endpointIp = "82.165.20.195";
      endpointPort = 51820;
      tunnelAddress = "10.8.0.20/32";
      environmentFile = "/var/lib/seedbox/gluetun/ionos-vps2-wireguard.env";
    };
  };

  personalInfra.services.prowlarr.enable = false;
  personalInfra.observability.exporters.enable = false;
  personalInfra.backup.restic.enable = false;

  services.qemuGuest.enable = true;
  services.fstrim.enable = true;

  boot.growPartition = true;
  boot.loader.grub.device = "/dev/vda";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # TODO: replace with the NAS-Kot backed VM disk or shared dataset path.
  fileSystems."/srv/seedbox" = {
    device = "/dev/disk/by-label/seedbox-data";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  system.stateVersion = "25.05";
}
