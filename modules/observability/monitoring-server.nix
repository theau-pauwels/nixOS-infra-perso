{ config, lib, ... }:

let
  cfg = config.personalInfra.observability.monitoringServer;
in
{
  options.personalInfra.observability.monitoringServer = {
    enable = lib.mkEnableOption "monitoring server skeleton";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Default local listen address for monitoring UIs.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.enable = lib.mkDefault true;
    services.grafana = {
      enable = lib.mkDefault true;
      settings.server.http_addr = lib.mkDefault cfg.listenAddress;
    };
    services.loki.enable = lib.mkDefault true;

    # TODO: configure scrape targets, retention, auth, backups, and VPN-only
    # reverse proxy exposure.
  };
}
