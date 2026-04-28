{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.personalInfra.networking.headscale;
  policyFormat = pkgs.formats.json { };
  policyFile = policyFormat.generate "headscale-policy.json" cfg.policy;
in
{
  options.personalInfra.networking.headscale = {
    enable = lib.mkEnableOption "Headscale control plane";

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://headscale.theau-vps.duckdns.org";
      description = "External URL clients use for the Headscale server.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local listen address. Prefer reverse proxy exposure.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Local Headscale listen port.";
    };

    baseDomain = lib.mkOption {
      type = lib.types.str;
      default = "tailnet.theau-vps.duckdns.org";
      description = "MagicDNS base domain. Must differ from the server URL host.";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "1.1.1.1"
        "9.9.9.9"
      ];
      description = "DNS resolvers pushed to clients.";
    };

    oidc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OIDC login for Headscale.";
      };

      issuer = lib.mkOption {
        type = lib.types.str;
        default = "https://auth.theau-vps.duckdns.org";
        description = "OIDC issuer URL.";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "headscale";
        description = "OIDC client id.";
      };

      clientSecretPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "/run/secrets/headscale-oidc-client-secret";
        description = "Path to OIDC client secret outside the Nix store.";
      };
    };

    policy = lib.mkOption {
      type = policyFormat.type;
      default = {
        groups = {
          "group:super-admin" = [ "theau@infra.local" ];
        };
        tagOwners = {
          "tag:server" = [ "group:super-admin" ];
          "tag:admin" = [ "group:super-admin" ];
        };
        acls = [
          {
            action = "accept";
            src = [ "group:super-admin" ];
            dst = [ "*:*" ];
          }
          {
            action = "accept";
            src = [ "*" ];
            dst = [
              "tag:server:80"
              "tag:server:443"
            ];
          }
        ];
        ssh = [
          {
            action = "accept";
            src = [ "group:super-admin" ];
            dst = [ "tag:server" ];
            users = [
              "theau"
              "root"
            ];
          }
        ];
      };
      description = "Headscale ACL policy skeleton. Keep identities generic until SSO is live.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.headscale = {
      enable = lib.mkDefault true;
      address = lib.mkDefault cfg.listenAddress;
      port = lib.mkDefault cfg.port;
      settings = {
        server_url = cfg.serverUrl;
        database.type = "sqlite";
        log.level = "info";
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
          allocation = "sequential";
        };
        dns = {
          magic_dns = true;
          base_domain = cfg.baseDomain;
          override_local_dns = true;
          nameservers.global = cfg.nameservers;
          search_domains = [ cfg.baseDomain ];
        };
        policy = {
          mode = "file";
          path = policyFile;
        };
        derp = {
          auto_update_enabled = true;
          update_frequency = "24h";
        };
      }
      // lib.optionalAttrs cfg.oidc.enable {
        oidc = {
          issuer = cfg.oidc.issuer;
          client_id = cfg.oidc.clientId;
          client_secret_path = cfg.oidc.clientSecretPath;
          scope = [
            "openid"
            "profile"
            "email"
          ];
          pkce.enabled = true;
        };
      };
    };

    # Headscale is normally reached through Caddy on 443. The local port stays
    # closed to the public firewall by default.
  };
}
