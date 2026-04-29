{ config, lib, pkgs, ... }:

let
  cfg = config.personalInfra.services.wikiOffline;
in
{
  options.personalInfra.services.wikiOffline = {
    enable = lib.mkEnableOption "offline wikipedia (kiwix)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8088;
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/srv/wiki";
    };
  };

  config = lib.mkIf cfg.enable {
    services.kiwix-serve = {
      enable = true;
      port = cfg.port;
      dataDir = cfg.dataDir;
    };
  };
}
