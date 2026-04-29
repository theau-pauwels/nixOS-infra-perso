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
    ../../modules/services/coolify.nix
    ../../modules/services/git.nix
    ../../modules/services/identity-provider.nix
    ../../modules/services/rustdesk.nix
    ../../modules/services/smtp.nix
    ../../modules/services/user-management.nix
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
  personalInfra.services.userManagement = {
    enable = true;
    authelia.domain = "auth.theau-vps.duckdns.org";
    lldap.domain = "users.theau-vps.duckdns.org";
    accessPolicies = {
      "users.theau-vps.duckdns.org" = {
        policy = "two_factor";
        groups = [ "admins" ];
      };
      "jellyfin.theau-vps.duckdns.org".groups = [
        "media-users"
        "media-admins"
        "admins"
      ];
      "jellyseerr.theau-vps.duckdns.org".groups = [
        "media-users"
        "media-admins"
        "admins"
      ];
      "seedbox.theau-vps.duckdns.org" = {
        policy = "two_factor";
        groups = [
          "media-admins"
          "admins"
        ];
      };
    };
  };

  personalInfra.services.rustdesk.enable = false;
  personalInfra.services.coolify.enable = false;
  personalInfra.services.git.enable = false;
  personalInfra.services.smtp.enable = false;
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
