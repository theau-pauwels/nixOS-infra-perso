{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/wireguard-site.nix
    ../../modules/networking/vlans.nix
    ../../modules/observability/exporters.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "mom-edge";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  # TODO: enable after interface names, gateway role, and routing policy are
  # known.
  personalInfra.networking.wireguardSite.enable = false;
  personalInfra.networking.vlans.enable = false;
  personalInfra.observability.exporters.enable = false;

  system.stateVersion = "25.05";
}
