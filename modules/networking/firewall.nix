{ config, lib, ... }:

let
  cfg = config.personalInfra.networking.firewall;
in
{
  options.personalInfra.networking.firewall = {
    enable = lib.mkEnableOption "personal infrastructure firewall baseline";

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Documented TCP ports to expose on this host.";
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Documented UDP ports to expose on this host.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      enable = lib.mkDefault true;
      allowedTCPPorts = lib.mkDefault cfg.allowedTCPPorts;
      allowedUDPPorts = lib.mkDefault cfg.allowedUDPPorts;
    };

    # TODO: add nftables-specific policy once host routing boundaries are known.
  };
}
