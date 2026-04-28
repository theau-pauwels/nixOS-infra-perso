{ ... }:

{
  imports = [
    ../../modules/common/base.nix
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

  # TODO: add real admin public keys from approved inventory.
  personalInfra.common.ssh.adminAuthorizedKeys = [ ];

  # TODO: configure outbound-only VPN behavior for Starlink CGNAT.
  personalInfra.networking.wireguardSite.enable = false;
  personalInfra.observability.exporters.enable = false;

  system.stateVersion = "25.05";
}
