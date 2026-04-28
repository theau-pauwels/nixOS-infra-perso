{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/services/jellyseerr.nix
    ../../modules/observability/exporters.nix
    ../../modules/backup/restic.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "jellyseerr-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      5055
    ];
  };

  personalInfra.services.jellyseerr = {
    enable = true;
    dataDir = "/srv/jellyseerr/config";
    port = 5055;
  };

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
  fileSystems."/srv/jellyseerr" = {
    device = "/dev/disk/by-label/jellyseerr-data";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  system.stateVersion = "25.05";
}
