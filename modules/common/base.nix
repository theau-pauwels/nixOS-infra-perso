{ config, lib, ... }:

let
  cfg = config.personalInfra.common.base;
in
{
  options.personalInfra.common.base = {
    enable = lib.mkEnableOption "personal infrastructure base defaults";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional hostname for this machine.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Brussels";
      description = "Default timezone for personal infrastructure hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = lib.mkIf (cfg.hostName != null) cfg.hostName;
    time.timeZone = lib.mkDefault cfg.timeZone;
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    # TODO: decide whether all hosts should share shell, editor, and Nix GC defaults.
    nix.settings.experimental-features = lib.mkDefault [
      "nix-command"
      "flakes"
    ];
  };
}
