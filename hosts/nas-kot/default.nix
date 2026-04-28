{ config, ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/backup/zfs.nix
    ../../modules/backup/restic.nix
    ../../modules/services/file-sharing.nix
    ../../modules/observability/exporters.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "nas-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  networking.interfaces.eno1.ipv4.addresses = [
    {
      address = "10.224.20.10";
      prefixLength = 24;
    }
  ];

  personalInfra.networking.firewall.enable = true;

  sops = {
    defaultSopsFile = ./secrets.enc.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets = {
      "restic/nas-kot-password" = { };
      "restic/nas-kot-repository" = { };
    };
  };

  personalInfra.backup.zfs = {
    enable = true;
    pools.nas = {
      topology = "raidz2";
      devices = [
        "/dev/disk/by-id/TODO-nas-disk-1"
        "/dev/disk/by-id/TODO-nas-disk-2"
        "/dev/disk/by-id/TODO-nas-disk-3"
        "/dev/disk/by-id/TODO-nas-disk-4"
        "/dev/disk/by-id/TODO-nas-disk-5"
        "/dev/disk/by-id/TODO-nas-disk-6"
      ];
    };
  };

  personalInfra.backup.restic = {
    enable = true;
    jobs.nas-kot-local = {
      paths = [
        "/etc/nixos"
        "/srv/nas/data"
      ];
      repositoryFile = config.sops.secrets."restic/nas-kot-repository".path;
      passwordFile = config.sops.secrets."restic/nas-kot-password".path;
      exclude = [
        "/srv/nas/media/transcode"
        "/srv/nas/**/.cache"
      ];
    };
  };

  personalInfra.services.fileSharing = {
    enable = true;
    lanInterface = "eno1";
    lanSubnets = [
      "10.224.10.0/24"
      "10.224.20.0/24"
      "100.64.0.0/10"
    ];
    fileBrowser.enable = true;
    shares = {
      data = {
        path = "/srv/nas/data";
        comment = "General NAS storage";
        validGroups = [ "nas-users" ];
        nfsClients = [
          "10.224.10.0/24"
          "10.224.20.0/24"
        ];
      };
      media = {
        path = "/srv/nas/media";
        comment = "Jellyfin media library";
        validGroups = [
          "nas-media"
          "nas-users"
        ];
        nfsClients = [ "10.224.20.0/24" ];
      };
      backups = {
        path = "/srv/nas/backups";
        comment = "Backup landing zone";
        validGroups = [ "nas-admins" ];
        nfsClients = [ "10.224.20.0/24" ];
      };
    };
  };

  personalInfra.observability.exporters.enable = false;

  boot.growPartition = true;
  boot.loader.grub.device = "/dev/sda";

  # TODO: replace with the real NAS boot disk identifier before installation.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.stateVersion = "25.05";
}
