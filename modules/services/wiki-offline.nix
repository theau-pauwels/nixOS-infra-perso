{ config, lib, ... }:

let
  cfg = config.personalInfra.services.wikiOffline;
in
{
  options.personalInfra.services.wikiOffline = {
    enable = lib.mkEnableOption "offline Wikipedia through kiwix-serve";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "kiwix-serve listen address. Keep LAN/VPN-only; never bind publicly.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = "kiwix-serve HTTP port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/wiki-offline";
      description = "Directory where ZIM files and optional library.xml live. Data is not stored in Git or the Nix store.";
    };

    library = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Named ZIM files to serve. Prefer runtime paths on NAS storage.";
    };

    libraryPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional Kiwix XML library file. Exclusive with library.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments passed to kiwix-serve.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the wiki port in the host firewall. Only use with a LAN/VPN bind address.";
    };

    allowedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.224.10.0/24"
        "10.224.20.0/24"
        "10.8.0.0/24"
        "100.64.0.0/10"
      ];
      description = "Documented LAN/VPN networks allowed to access the service.";
    };

    reverseProxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Create a Caddy virtual host for the offline wiki.";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "wiki.internal";
        description = "Internal DNS name for the offline wiki.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional Caddy directives for the offline wiki virtual host.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.library == { }) != (cfg.libraryPath == null);
        message = "personalInfra.services.wikiOffline requires exactly one of library or libraryPath.";
      }
      {
        assertion =
          !(
            cfg.openFirewall
            && builtins.elem cfg.bindAddress [
              "all"
              "0.0.0.0"
              "::"
            ]
          );
        message = "personalInfra.services.wikiOffline.openFirewall requires a concrete LAN/VPN bindAddress.";
      }
      {
        assertion = lib.all (
          network:
          !(builtins.elem network [
            "0.0.0.0/0"
            "::/0"
          ])
        ) cfg.allowedNetworks;
        message = "personalInfra.services.wikiOffline.allowedNetworks must not include public default routes.";
      }
    ];

    services.kiwix-serve = {
      enable = true;
      address = cfg.bindAddress;
      port = cfg.port;
      openFirewall = cfg.openFirewall;
      library = cfg.library;
      libraryPath = cfg.libraryPath;
      extraArgs = cfg.extraArgs;
    };

    services.caddy = lib.mkIf cfg.reverseProxy.enable {
      enable = lib.mkDefault true;
      virtualHosts.${cfg.reverseProxy.domain}.extraConfig = ''
        encode zstd gzip
        reverse_proxy http://${cfg.bindAddress}:${toString cfg.port}
        ${cfg.reverseProxy.extraConfig}
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root - -"
    ];
  };
}
