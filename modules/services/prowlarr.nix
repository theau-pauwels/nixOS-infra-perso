{ config, lib, ... }:

let
  cfg = config.personalInfra.services.prowlarr;
  caddyAuthConfig = ''
    forward_auth ${cfg.reverseProxy.authelia.upstream} {
      uri /api/verify?rd=${cfg.reverseProxy.authelia.redirectUrl}
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
  '';
in
{
  options.personalInfra.services.prowlarr = {
    enable = lib.mkEnableOption "Prowlarr indexer aggregator";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Prowlarr web UI bind address. Keep LAN/VPN-only.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9696;
      description = "Prowlarr web UI port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prowlarr";
      description = "Prowlarr persistent data directory.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Prowlarr port in the host firewall. Only use with LAN/VPN bind addresses.";
    };

    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.224.20.0/24"
        "10.8.0.0/24"
        "100.64.0.0/10"
      ];
      description = "Documented LAN/VPN networks allowed to reach Prowlarr.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Runtime environment files for Prowlarr secrets. Use PROWLARR__SECTION__KEY=value entries.";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Documented runtime path for the Prowlarr API key used by Jellyseerr/qBittorrent integration.";
    };

    integrations = {
      jellyseerrUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://jellyseerr-kot.tailnet.theau-vps.duckdns.org:5055";
        description = "LAN/VPN Jellyseerr URL documented for manual app integration.";
      };

      qbittorrentUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8080";
        description = "qBittorrent WebUI URL, expected to be exposed by the Gluetun network namespace.";
      };

      gluetunService = lib.mkOption {
        type = lib.types.str;
        default = "podman-seedbox-gluetun.service";
        description = "Systemd unit that provides the Gluetun VPN container for qBittorrent.";
      };

      requireGluetun = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Order Prowlarr after Gluetun so qBittorrent integration is not started before VPN egress exists.";
      };
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Create a Caddy virtual host for Prowlarr.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "prowlarr.internal";
        description = "Internal DNS name for Prowlarr.";
      };

      useAuthelia = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Protect the Prowlarr UI with Authelia ForwardAuth.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional Caddy directives for the Prowlarr virtual host.";
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
        assertion =
          !(
            cfg.openFirewall
            && builtins.elem cfg.bindAddress [
              "all"
              "*"
              "0.0.0.0"
              "::"
            ]
          );
        message = "personalInfra.services.prowlarr.openFirewall requires a concrete LAN/VPN bindAddress.";
      }
      {
        assertion = lib.all (
          network:
          !(builtins.elem network [
            "0.0.0.0/0"
            "::/0"
          ])
        ) cfg.allowedNetworks;
        message = "personalInfra.services.prowlarr.allowedNetworks must not include public default routes.";
      }
      {
        assertion = cfg.apiKeyFile == null || !(lib.hasPrefix "/nix/store/" (toString cfg.apiKeyFile));
        message = "personalInfra.services.prowlarr.apiKeyFile must be a runtime secret path outside the Nix store.";
      }
    ];

    services.prowlarr = {
      enable = true;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
      environmentFiles = cfg.environmentFiles;
      settings = {
        update = {
          mechanism = "external";
          automatically = false;
        };
        log.analyticsEnabled = false;
        server = {
          bindaddress = cfg.bindAddress;
          port = cfg.port;
        };
      };
    };

    systemd.services.prowlarr = lib.mkIf cfg.integrations.requireGluetun {
      after = [ cfg.integrations.gluetunService ];
      wants = [ cfg.integrations.gluetunService ];
    };

    services.caddy = lib.mkIf cfg.reverseProxy.enable {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.reverseProxy.domain}.extraConfig = ''
        ${lib.optionalString cfg.reverseProxy.useAuthelia caddyAuthConfig}
        encode zstd gzip
        reverse_proxy http://${cfg.bindAddress}:${toString cfg.port}
        ${cfg.reverseProxy.extraConfig}
      '';
    };
  };
}
