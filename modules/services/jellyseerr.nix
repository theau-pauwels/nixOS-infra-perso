{ config, lib, ... }:

let
  cfg = config.personalInfra.services.jellyseerr;
in
{
  options.personalInfra.services.jellyseerr = {
    enable = lib.mkEnableOption "Jellyseerr request management service";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/srv/jellyseerr/config";
      description = "Persistent Jellyseerr configuration directory.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Jellyseerr web UI port.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Jellyseerr web UI port on the host firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.seerr = {
      enable = lib.mkDefault true;
      port = lib.mkDefault cfg.port;
      configDir = lib.mkDefault cfg.dataDir;
      openFirewall = lib.mkDefault cfg.openFirewall;
    };

    # TODO: configure Jellyfin and qBittorrent integration in Jellyseerr after
    # service URLs and SSO/OIDC client settings are finalized.
  };
}
