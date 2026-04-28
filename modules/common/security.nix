{ config, lib, ... }:

let
  cfg = config.personalInfra.common.security;
in
{
  options.personalInfra.common.security = {
    enable = lib.mkEnableOption "common security defaults";

    allowPing = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether hosts should respond to ICMP echo requests.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      enable = lib.mkDefault true;
      allowPing = lib.mkDefault cfg.allowPing;
    };

    security.sudo.wheelNeedsPassword = lib.mkDefault true;

    # TODO: evaluate apparmor/auditd defaults per host role before enabling.
  };
}
