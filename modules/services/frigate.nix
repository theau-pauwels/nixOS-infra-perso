{ config, lib, ... }:

let
  cfg = config.personalInfra.services.frigate;
in
{
  options.personalInfra.services.frigate = {
    enable = lib.mkEnableOption "Frigate NVR";

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "frigate.mom.lan";
      description = "Internal Frigate hostname.";
    };

    storagePath = lib.mkOption {
      type = lib.types.str;
      default = "/srv/frigate";
      description = "Local storage root for Frigate media.";
    };

    cameras = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Camera configuration placeholders. Keep camera credentials out of Git.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.frigate = {
      enable = true;
      hostname = cfg.hostname;
      checkConfig = false;
      settings = {
        mqtt.enabled = false;
        cameras = cfg.cameras;
        record = {
          enabled = true;
          retain.days = 3;
        };
        snapshots = {
          enabled = true;
          retain.default = 3;
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.storagePath} 0750 frigate frigate - -"
      "d ${cfg.storagePath}/media 0750 frigate frigate - -"
      "d ${cfg.storagePath}/config 0750 frigate frigate - -"
    ];
  };
}
