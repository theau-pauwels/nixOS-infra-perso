{ config, lib, ... }:

let
  cfg = config.personalInfra.backup.restic;
in
{
  options.personalInfra.backup.restic = {
    enable = lib.mkEnableOption "Restic backup skeleton";

    jobs = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Future restic job definitions. Use password files, not inline secrets.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.backups = cfg.jobs;

    # TODO: define repositories, passwordFile paths, retention, and restore
    # tests. Never put repository passwords inline.
  };
}
