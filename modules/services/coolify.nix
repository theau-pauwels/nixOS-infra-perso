{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.personalInfra.services.coolify;
  composeFileArgs = lib.concatMapStringsSep " " (
    file: "-f ${lib.escapeShellArg file}"
  ) cfg.composeFiles;
  composeBaseCommand = "${pkgs.docker-compose}/bin/docker-compose --env-file ${lib.escapeShellArg (toString cfg.environmentFile)} ${composeFileArgs}";
  caddyAuthConfig = ''
    forward_auth ${cfg.reverseProxy.authelia.upstream} {
      uri /api/verify?rd=${cfg.reverseProxy.authelia.redirectUrl}
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
  '';
in
{
  options.personalInfra.services.coolify = {
    enable = lib.mkEnableOption "Coolify self-hosted PaaS";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "coolify.example.invalid";
      description = "Domain for the Coolify administration UI.";
    };

    wildcardDomain = lib.mkOption {
      type = lib.types.str;
      default = "*.theau.net";
      description = "Wildcard application domain managed by DNS and the selected edge proxy.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/coolify";
      description = "Coolify persistent data root.";
    };

    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/source";
      description = "Directory containing the official Coolify Compose files.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      default = "/data/coolify/source/.env";
      description = "Runtime Coolify environment file. It contains secrets and must not be committed.";
    };

    composeFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [
        "/data/coolify/source/docker-compose.yml"
        "/data/coolify/source/docker-compose.prod.yml"
      ];
      description = "Coolify Docker Compose files managed outside Git, usually from the official installer bundle.";
    };

    adminBindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address where the Coolify admin UI is expected to listen.";
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Coolify admin UI port.";
    };

    openAdminFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the admin UI port directly. Prefer Caddy with Authelia instead.";
    };

    dockerNetwork = lib.mkOption {
      type = lib.types.str;
      default = "coolify";
      description = "Docker network name expected by Coolify-managed workloads.";
    };

    reverseProxy = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "caddy-edge"
          "traefik-internal"
          "none"
        ];
        default = "caddy-edge";
        description = "Reverse-proxy ownership model for Coolify.";
      };

      protectAdminWithAuthelia = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Protect the Coolify administration UI with Authelia ForwardAuth.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional Caddy directives for the Coolify admin virtual host.";
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
        assertion = !(lib.hasPrefix "/nix/store/" (toString cfg.environmentFile));
        message = "personalInfra.services.coolify.environmentFile must be a runtime secret path outside the Nix store.";
      }
      {
        assertion = cfg.reverseProxy.mode != "caddy-edge" || cfg.reverseProxy.protectAdminWithAuthelia;
        message = "Coolify admin must remain protected when exposed through the Caddy edge proxy.";
      }
      {
        assertion =
          !(
            cfg.openAdminFirewall
            && builtins.elem cfg.adminBindAddress [
              "all"
              "0.0.0.0"
              "::"
            ]
          );
        message = "personalInfra.services.coolify.openAdminFirewall requires a concrete LAN/VPN adminBindAddress.";
      }
    ];

    virtualisation.docker.enable = true;

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
      "d ${cfg.sourceDir} 0750 root root - -"
    ];

    systemd.services.coolify = {
      description = "Coolify PaaS Docker Compose stack";
      after = [
        "docker.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.docker
        pkgs.docker-compose
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = cfg.sourceDir;
        ExecStart = "${pkgs.bash}/bin/bash -lc ${lib.escapeShellArg "${composeBaseCommand} up -d --remove-orphans"}";
        ExecStop = "${pkgs.bash}/bin/bash -lc ${lib.escapeShellArg "${composeBaseCommand} down"}";
        TimeoutStartSec = "15min";
        TimeoutStopSec = "5min";
      };
    };

    services.caddy = lib.mkIf (cfg.reverseProxy.mode == "caddy-edge") {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.domain}.extraConfig = ''
        ${lib.optionalString cfg.reverseProxy.protectAdminWithAuthelia caddyAuthConfig}
        encode zstd gzip
        reverse_proxy http://${cfg.adminBindAddress}:${toString cfg.adminPort}
        ${cfg.reverseProxy.extraConfig}
      '';
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openAdminFirewall [ cfg.adminPort ];
  };
}
