{ config, lib, ... }:

let
  cfg = config.personalInfra.common.ssh;
in
{
  options.personalInfra.common.ssh = {
    enable = lib.mkEnableOption "hardened OpenSSH baseline";

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "theau";
      description = "Local admin account that receives break-glass SSH keys.";
    };

    adminAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFAKEPLACEHOLDER admin@example" ];
      description = "Public admin SSH keys. Never put private keys here.";
    };

    createAdminUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the local break-glass admin user.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
        PubkeyAuthentication = lib.mkDefault true;
        X11Forwarding = lib.mkDefault false;
      };
    };

    users.groups.${cfg.adminUser} = lib.mkIf cfg.createAdminUser { };
    users.users.${cfg.adminUser} = {
      isNormalUser = lib.mkIf cfg.createAdminUser true;
      group = lib.mkIf cfg.createAdminUser cfg.adminUser;
      extraGroups = lib.mkIf cfg.createAdminUser [ "wheel" ];
      openssh.authorizedKeys.keys = cfg.adminAuthorizedKeys;
    };

    # TODO: add future trusted SSH user CA public key support separately from
    # personal break-glass admin keys.
  };
}
