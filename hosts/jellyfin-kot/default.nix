{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/services/seedbox.nix
    ../../modules/observability/exporters.nix
    ../../modules/backup/restic.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "jellyfin-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  # TODO: enable after auditing the existing /opt/seedbox deployment.
  personalInfra.services.seedbox.enable = false;
  personalInfra.observability.exporters.enable = false;
  personalInfra.backup.restic.enable = false;

  system.stateVersion = "25.05";
}
