{ config, lib, ... }:

let
  cfg = config.personalInfra.networking.headscale;
in
{
  options.personalInfra.networking.headscale = {
    enable = lib.mkEnableOption "Headscale control plane skeleton";

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://headscale.example.invalid";
      description = "External URL clients use for the Headscale server.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local listen address. Prefer reverse proxy exposure.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Local Headscale listen port.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = lib.mkDefault true;
      address = lib.mkDefault cfg.listenAddress;
      port = lib.mkDefault cfg.port;
      settings.server_url = lib.mkDefault cfg.serverUrl;
    };

    # TODO: configure DNS, OIDC, ACLs, users, and secret material.
  };
}
