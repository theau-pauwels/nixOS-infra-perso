{ config, lib, ... }:

let
  cfg = config.personalInfra.backup.restic;
in
{
  options.personalInfra.backup.restic = {
    enable = lib.mkEnableOption "Restic backups";

    jobs = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Restic job definitions. Use SOPS-backed passwordFile/repositoryFile paths, not inline secrets.";
    };

    defaultPruneOpts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      description = "Default restic forget/prune policy for jobs that do not override it.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (job: (job ? passwordFile) || (job ? environmentFile)) (
          lib.attrValues cfg.jobs
        );
        message = "Every personalInfra.backup.restic job must use passwordFile or environmentFile, preferably from sops-nix.";
      }
      {
        assertion = lib.all (job: !(job ? password)) (lib.attrValues cfg.jobs);
        message = "Restic passwords must never be configured inline.";
      }
    ];

    services.restic.backups = lib.mapAttrs (
      _name: job:
      {
        initialize = lib.mkDefault false;
        pruneOpts = lib.mkDefault cfg.defaultPruneOpts;
        runCheck = lib.mkDefault true;
        checkOpts = lib.mkDefault [ "--read-data-subset=1G" ];
        timerConfig = lib.mkDefault {
          OnCalendar = "03:30";
          RandomizedDelaySec = "45m";
          Persistent = true;
        };
      }
      // job
    ) cfg.jobs;
  };
}
