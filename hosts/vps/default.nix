{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/headscale.nix
    ../../modules/services/caddy.nix
    ../../modules/services/rustdesk.nix
    ../../modules/observability/exporters.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "vps";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  # TODO: enable future native VPS services only after the Ubuntu bundle
  # migration plan is tested.
  personalInfra.networking.headscale.enable = false;
  personalInfra.services.caddy.enable = false;
  personalInfra.services.rustdesk.enable = false;
  personalInfra.observability.exporters.enable = false;

  system.stateVersion = "25.05";
}
