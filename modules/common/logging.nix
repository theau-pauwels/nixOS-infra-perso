{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.personalInfra.common.logging;
in
{
  options.personalInfra.common.logging = {
    enable = lib.mkEnableOption "bounded local logging";

    journalMaxUse = lib.mkOption {
      type = lib.types.str;
      default = "512M";
      description = "Maximum persistent systemd journal size.";
    };

    journalKeepFree = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "Free space systemd-journald must leave on the filesystem.";
    };

    journalMaxFileSize = lib.mkOption {
      type = lib.types.str;
      default = "64M";
      description = "Maximum size of one journal file before rotation.";
    };

    journalMaxRetention = lib.mkOption {
      type = lib.types.str;
      default = "14day";
      description = "Maximum retention time for persistent journal entries.";
    };

    vacuumSize = lib.mkOption {
      type = lib.types.str;
      default = "384M";
      description = "Target journal size for the daily vacuum guard.";
    };

    logrotateSize = lib.mkOption {
      type = lib.types.str;
      default = "50M";
      description = "Rotate text logs early when they reach this size.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.journald.extraConfig = ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=${cfg.journalMaxUse}
      SystemKeepFree=${cfg.journalKeepFree}
      SystemMaxFileSize=${cfg.journalMaxFileSize}
      MaxRetentionSec=${cfg.journalMaxRetention}
    '';

    services.logrotate = {
      enable = true;
      settings = {
        header = {
          global = true;
          frequency = "daily";
          rotate = 7;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          copytruncate = true;
        };
        "/var/log/*.log" = {
          size = cfg.logrotateSize;
        };
        "/var/log/samba/*.log" = {
          size = cfg.logrotateSize;
        };
      };
    };

    systemd.services.personal-infra-journal-vacuum = {
      description = "Vacuum persistent journal below the configured NAS guard size";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/journalctl --vacuum-size=${cfg.vacuumSize}";
      };
    };

    systemd.timers.personal-infra-journal-vacuum = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
    };
  };
}
