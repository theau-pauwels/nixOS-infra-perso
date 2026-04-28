{ config, lib, ... }:

let
  cfg = config.personalInfra.services.caddy;
in
{
  options.personalInfra.services.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy skeleton";

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Future Caddy virtual host definitions.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = lib.mkDefault true;
      virtualHosts = cfg.virtualHosts;
    };

    networking.firewall.allowedTCPPorts = lib.mkDefault [
      80
      443
    ];

    # TODO: add DNS provider credentials through secret files only.
  };
}
