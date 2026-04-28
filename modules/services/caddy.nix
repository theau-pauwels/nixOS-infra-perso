{ config, lib, ... }:

let
  cfg = config.personalInfra.services.caddy;

  needsAuthelia = hostCfg: hostCfg.authPolicy != "public";

  mkAutheliaForwardAuth = ''
    forward_auth 127.0.0.1:9091 {
      uri /api/verify?rd=${cfg.authRedirectUrl}
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
  '';

  mkReverseProxy = upstream: ''
    encode zstd gzip
    reverse_proxy ${upstream}
  '';
in
{
  options.personalInfra.services.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy";

    email = lib.mkOption {
      type = lib.types.str;
      default = "theau.pauwels@gmail.com";
      description = "ACME account email.";
    };

    authRedirectUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://auth.theau-vps.duckdns.org/";
      description = "Authelia redirect URL used by Caddy forward_auth.";
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            upstream = lib.mkOption {
              type = lib.types.str;
              description = "Reverse proxy upstream URL.";
            };
            authPolicy = lib.mkOption {
              type = lib.types.enum [
                "public"
                "authenticated"
                "super-admin"
              ];
              default = "authenticated";
              description = "Authelia policy expected for this virtual host.";
            };
            extraConfig = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Additional Caddyfile directives for this host.";
            };
          };
        }
      );
      default = {
        "headscale.theau-vps.duckdns.org" = {
          upstream = "http://127.0.0.1:8081";
          authPolicy = "public";
        };
        "auth.theau-vps.duckdns.org" = {
          upstream = "http://127.0.0.1:9091";
          authPolicy = "public";
        };
        "users.theau-vps.duckdns.org" = {
          upstream = "http://127.0.0.1:17170";
          authPolicy = "super-admin";
        };
        "jellyfin.theau-vps.duckdns.org" = {
          upstream = "http://jellyfin-kot.tailnet.theau-vps.duckdns.org:8096";
          authPolicy = "authenticated";
        };
        "seedbox.theau-vps.duckdns.org" = {
          upstream = "http://seedbox-kot.tailnet.theau-vps.duckdns.org:8080";
          authPolicy = "super-admin";
        };
        "jellyseerr.theau-vps.duckdns.org" = {
          upstream = "http://jellyseerr-kot.tailnet.theau-vps.duckdns.org:5055";
          authPolicy = "authenticated";
        };
      };
      description = "Public virtual hosts and upstreams.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = lib.mkDefault true;
      email = lib.mkDefault cfg.email;
      globalConfig = ''
        email ${cfg.email}
      '';
      virtualHosts = lib.mapAttrs (_host: hostCfg: {
        extraConfig = ''
          ${lib.optionalString (needsAuthelia hostCfg) mkAutheliaForwardAuth}
          ${mkReverseProxy hostCfg.upstream}
          ${hostCfg.extraConfig}
        '';
      }) cfg.virtualHosts;
    };

    networking.firewall.allowedTCPPorts = lib.mkDefault [
      80
      443
    ];
  };
}
