{ config, lib, ... }:

let
  cfg = config.personalInfra.observability.exporters;
in
{
  options.personalInfra.observability.exporters = {
    enable = lib.mkEnableOption "observability exporters skeleton";

    nodeExporter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Prometheus node exporter.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node.enable = lib.mkDefault cfg.nodeExporter;

    # TODO: add service-specific exporters per host role.
  };
}
