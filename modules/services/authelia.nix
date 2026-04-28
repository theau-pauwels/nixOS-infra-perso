{ config, lib, ... }:

let
  cfg = config.personalInfra.services.authelia;
in
{
  options.personalInfra.services.authelia = {
    enable = lib.mkEnableOption "Authelia SSO skeleton";

    instanceName = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Authelia instance name.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.authelia.instances.${cfg.instanceName} = {
      enable = lib.mkDefault true;
      settings = {
        theme = lib.mkDefault "dark";
        default_2fa_method = lib.mkDefault "totp";
      };
    };

    # TODO: configure storage, notifier, session, JWT, and OIDC secrets through
    # files outside the Nix store before enabling in production.
  };
}
