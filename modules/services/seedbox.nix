{ config, lib, ... }:

let
  cfg = config.personalInfra.services.seedbox;
in
{
  options.personalInfra.services.seedbox = {
    enable = lib.mkEnableOption "Jellyfin and qBittorrent seedbox skeleton";

    dataRoot = lib.mkOption {
      type = lib.types.path;
      default = "/srv/seedbox";
      description = "Root path for seedbox persistent data.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = lib.mkDefault true;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataRoot} 0750 root root - -"
      "d ${cfg.dataRoot}/downloads 0750 root root - -"
      "d ${cfg.dataRoot}/media 0750 root root - -"
    ];

    # TODO: model qBittorrent and gluetun/VPN behavior after auditing the
    # current jellyfin_kot VM. Do not expose the torrent UI publicly.
  };
}
