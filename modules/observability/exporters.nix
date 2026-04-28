{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.personalInfra.observability.exporters;
  blackboxConfig = pkgs.formats.yaml { };
in
{
  options.personalInfra.observability.exporters = {
    enable = lib.mkEnableOption "observability exporters skeleton";

    nodeExporter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Prometheus node exporter.";
    };

    blackboxExporter = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Prometheus blackbox exporter.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Listen address for enabled exporters.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = lib.mkIf cfg.nodeExporter {
      enable = true;
      listenAddress = cfg.listenAddress;
      openFirewall = false;
    };

    services.prometheus.exporters.blackbox = lib.mkIf cfg.blackboxExporter {
      enable = true;
      listenAddress = cfg.listenAddress;
      openFirewall = false;
      configFile = blackboxConfig.generate "blackbox-exporter.yaml" {
        modules = {
          http_2xx = {
            prober = "http";
            timeout = "5s";
            http = {
              valid_http_versions = [
                "HTTP/1.1"
                "HTTP/2.0"
              ];
              follow_redirects = true;
              preferred_ip_protocol = "ip4";
            };
          };
          icmp = {
            prober = "icmp";
            timeout = "5s";
          };
        };
      };
    };
  };
}
