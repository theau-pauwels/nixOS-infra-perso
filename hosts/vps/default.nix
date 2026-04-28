{ ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/networking/headscale.nix
    ../../modules/services/authelia.nix
    ../../modules/services/caddy.nix
    ../../modules/services/identity-provider.nix
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

  personalInfra.networking.headscale = {
    enable = true;
    serverUrl = "https://headscale.theau-vps.duckdns.org";
    baseDomain = "tailnet.theau-vps.duckdns.org";
  };

  personalInfra.services.caddy.enable = true;
  personalInfra.services.identityProvider.enable = true;
  personalInfra.services.authelia = {
    enable = true;
    services = {
      "users.theau-vps.duckdns.org".groups = [ "super-admin" ];
      "jellyfin.theau-vps.duckdns.org".groups = [ ];
      "jellyseerr.theau-vps.duckdns.org".groups = [ ];
      "seedbox.theau-vps.duckdns.org".groups = [ "super-admin" ];
    };
  };

  personalInfra.services.rustdesk.enable = false;
  personalInfra.observability.exporters.enable = false;

  boot.growPartition = true;
  boot.loader.grub.device = "/dev/vda";

  # TODO: replace with the real native VPS disk identifier before phase 7.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.stateVersion = "25.05";
}
