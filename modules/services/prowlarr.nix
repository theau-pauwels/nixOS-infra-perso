{ config, lib, pkgs, ... }:

let
  cfg = config.personalInfra.services.prowlarr;
in
{
  options.personalInfra.services.prowlarr = {
    enable = lib.mkEnableOption "Prowlarr indexer aggregator";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/prowlarr";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prowlarr = {
      enable = true;
      port = cfg.port;
      dataDir = cfg.dataDir;
    };
  };
}
