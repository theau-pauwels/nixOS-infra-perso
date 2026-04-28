{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/backup/zfs.nix
    ../../modules/backup/restic.nix
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

  # SAFE: disabled until disk identifiers, pool layout, backups, and restore
  # testing are documented.
  personalInfra.backup.zfs.enable = false;
  personalInfra.backup.restic.enable = false;
  personalInfra.observability.exporters.enable = false;

  system.stateVersion = "25.05";
}
