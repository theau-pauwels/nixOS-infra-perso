{ config, lib, ... }:

let
  cfg = config.personalInfra.services.git;
  caddyAuthConfig = ''
    forward_auth ${cfg.reverseProxy.authelia.upstream} {
      uri /api/verify?rd=${cfg.reverseProxy.authelia.redirectUrl}
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
  '';
in
{
  options.personalInfra.services.git = {
    enable = lib.mkEnableOption "self-hosted Git platform (Forgejo)";

    appName = lib.mkOption {
      type = lib.types.str;
      default = "Theau Git";
      description = "Forgejo display name.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.example.invalid";
      description = "External HTTP(S) domain for Forgejo.";
    };

    httpBindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local address for the Forgejo web UI.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Local Forgejo HTTP port.";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Forgejo built-in SSH port for Git clone/push traffic.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/forgejo";
      description = "Forgejo persistent state directory.";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Documented bootstrap admin username placeholder. No password is configured by this module.";
    };

    allowRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow public self-registration. Keep false for personal infrastructure.";
    };

    openHttpFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the local HTTP port directly. Prefer Caddy instead.";
    };

    openSshFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the Forgejo SSH port on this host.";
    };

    database = {
      type = lib.mkOption {
        type = lib.types.enum [
          "sqlite3"
          "postgres"
          "mysql"
        ];
        default = "sqlite3";
        description = "Forgejo database backend.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Runtime database password file for non-sqlite deployments.";
      };
    };

    lfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Git LFS storage under the Forgejo data directory.";
      };
    };

    backup = {
      dump = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the Forgejo dump timer for backup-friendly archives.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "04:20";
          description = "systemd calendar expression for Forgejo dumps.";
        };

        directory = lib.mkOption {
          type = lib.types.str;
          default = "${cfg.dataDir}/dump";
          description = "Directory where Forgejo dump archives are written.";
        };
      };
    };

    mailer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable outbound mail through the internal SMTP relay.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "smtp.infra.theau.local";
        description = "SMTP relay hostname.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "SMTP relay port.";
      };

      from = lib.mkOption {
        type = lib.types.str;
        default = "git@example.invalid";
        description = "Sender address for Forgejo notifications.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional SMTP username if the internal relay requires authentication.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional SMTP password file. Leave null for IP-trusted internal relay mode.";
      };
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Create a Caddy virtual host for Forgejo.";
      };

      useAuthelia = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Protect the Forgejo web UI with Authelia ForwardAuth.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional Caddy directives for the Forgejo virtual host.";
      };

      authelia = {
        upstream = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:9091";
          description = "Authelia ForwardAuth upstream.";
        };

        redirectUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://auth.theau-vps.duckdns.org/";
          description = "Authelia login redirect URL.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.allowRegistration;
        message = "personalInfra.services.git.allowRegistration must stay false unless a production abuse policy is added.";
      }
      {
        assertion = cfg.database.type == "sqlite3" || cfg.database.passwordFile != null;
        message = "personalInfra.services.git.database.passwordFile is required for non-sqlite database backends.";
      }
      {
        assertion =
          cfg.mailer.passwordFile == null
          || !(lib.hasPrefix "/nix/store/" (toString cfg.mailer.passwordFile));
        message = "personalInfra.services.git.mailer.passwordFile must be a runtime secret path outside the Nix store.";
      }
    ];

    services.forgejo = {
      enable = true;
      stateDir = cfg.dataDir;
      database = {
        type = cfg.database.type;
        passwordFile = cfg.database.passwordFile;
      };
      lfs.enable = cfg.lfs.enable;
      dump = {
        enable = cfg.backup.dump.enable;
        interval = cfg.backup.dump.interval;
        backupDir = cfg.backup.dump.directory;
      };
      settings = {
        DEFAULT.APP_NAME = cfg.appName;
        server = {
          DOMAIN = cfg.domain;
          ROOT_URL = "https://${cfg.domain}/";
          HTTP_ADDR = cfg.httpBindAddress;
          HTTP_PORT = cfg.httpPort;
          DISABLE_SSH = false;
          START_SSH_SERVER = true;
          SSH_LISTEN_PORT = cfg.sshPort;
          SSH_PORT = cfg.sshPort;
        };
        service = {
          DISABLE_REGISTRATION = !cfg.allowRegistration;
          REQUIRE_SIGNIN_VIEW = cfg.reverseProxy.useAuthelia;
        };
        session.COOKIE_SECURE = cfg.reverseProxy.enable;
        actions.ENABLED = false;
        "cron.update_checker".ENABLED = false;
        log.LEVEL = "Info";
      }
      // lib.optionalAttrs cfg.mailer.enable {
        mailer = {
          ENABLED = true;
          PROTOCOL = "smtp";
          SMTP_ADDR = cfg.mailer.host;
          SMTP_PORT = toString cfg.mailer.port;
          FROM = cfg.mailer.from;
          USER = cfg.mailer.user;
        };
      };
      secrets = lib.optionalAttrs (cfg.mailer.enable && cfg.mailer.passwordFile != null) {
        mailer.PASSWD = cfg.mailer.passwordFile;
      };
    };

    services.caddy = lib.mkIf cfg.reverseProxy.enable {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.domain}.extraConfig = ''
        ${lib.optionalString cfg.reverseProxy.useAuthelia caddyAuthConfig}
        encode zstd gzip
        reverse_proxy http://${cfg.httpBindAddress}:${toString cfg.httpPort}
        ${cfg.reverseProxy.extraConfig}
      '';
    };

    networking.firewall.allowedTCPPorts =
      (lib.optional cfg.openHttpFirewall cfg.httpPort) ++ (lib.optional cfg.openSshFirewall cfg.sshPort);
  };
}
