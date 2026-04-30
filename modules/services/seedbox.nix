{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.personalInfra.services.seedbox;
  gluetunContainerName = "seedbox-gluetun";
in
{
  options.personalInfra.services.seedbox = {
    enable = lib.mkEnableOption "qBittorrent and gluetun seedbox";

    dataRoot = lib.mkOption {
      type = lib.types.path;
      default = "/srv/seedbox";
      description = "Root path for seedbox persistent data.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 991;
      description = "Numeric UID used by seedbox containers.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 991;
      description = "Numeric GID used by seedbox containers.";
    };

    gluetun = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable gluetun WireGuard egress container.";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/qmcgaw/gluetun:latest";
        description = "OCI image used for gluetun.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/seedbox/gluetun/ionos-vps2-wireguard.env";
        description = "Environment file containing WireGuard secrets outside the Nix store.";
      };

      endpointIp = lib.mkOption {
        type = lib.types.str;
        default = "82.165.20.195";
        description = "WireGuard endpoint IP. Current default is IONOS-VPS2 in Germany.";
      };

      endpointPort = lib.mkOption {
        type = lib.types.port;
        default = 51820;
        description = "WireGuard endpoint UDP port on IONOS-VPS2.";
      };

      tunnelAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.8.0.20/32";
        description = "Current jellyfin_kot WireGuard peer address.";
      };

      allowedOutboundSubnets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "10.224.10.0/24"
          "10.224.20.0/24"
        ];
        description = "Subnets allowed through gluetun firewall for LAN/VPN access to qBittorrent.";
      };
    };

    qbittorrent = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable qBittorrent behind gluetun.";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "lscr.io/linuxserver/qbittorrent:latest";
        description = "OCI image used for qBittorrent.";
      };

      webuiPort = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "qBittorrent WebUI port exposed through gluetun.";
      };

      torrentPort = lib.mkOption {
        type = lib.types.port;
        default = 6881;
        description = "qBittorrent torrenting port exposed through gluetun.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.seedbox.gid = lib.mkDefault cfg.gid;
    users.users.seedbox = {
      isSystemUser = true;
      group = "seedbox";
      uid = lib.mkDefault cfg.uid;
      home = cfg.dataRoot;
      createHome = false;
    };

    virtualisation.podman.enable = lib.mkDefault (cfg.gluetun.enable || cfg.qbittorrent.enable);
    virtualisation.oci-containers.backend = lib.mkDefault "podman";

    virtualisation.oci-containers.containers = lib.mkMerge [
      (lib.mkIf cfg.gluetun.enable {
        ${gluetunContainerName} = {
          image = cfg.gluetun.image;
          autoStart = true;
          capabilities.NET_ADMIN = true;
          devices = [ "/dev/net/tun:/dev/net/tun" ];
          environment = {
            VPN_SERVICE_PROVIDER = "custom";
            VPN_TYPE = "wireguard";
            WIREGUARD_ENDPOINT_IP = cfg.gluetun.endpointIp;
            WIREGUARD_ENDPOINT_PORT = toString cfg.gluetun.endpointPort;
            WIREGUARD_ADDRESSES = cfg.gluetun.tunnelAddress;
            FIREWALL = "on";
            FIREWALL_VPN_INPUT_PORTS = lib.concatStringsSep "," [
              (toString cfg.qbittorrent.webuiPort)
              (toString cfg.qbittorrent.torrentPort)
            ];
            FIREWALL_OUTBOUND_SUBNETS = lib.concatStringsSep "," cfg.gluetun.allowedOutboundSubnets;
            TZ = config.time.timeZone;
          };
          environmentFiles = [ cfg.gluetun.environmentFile ];
          ports = [
            "${toString cfg.qbittorrent.webuiPort}:${toString cfg.qbittorrent.webuiPort}/tcp"
            "${toString cfg.qbittorrent.torrentPort}:${toString cfg.qbittorrent.torrentPort}/tcp"
            "${toString cfg.qbittorrent.torrentPort}:${toString cfg.qbittorrent.torrentPort}/udp"
          ];
          volumes = [
            "${cfg.dataRoot}/gluetun:/gluetun"
          ];
          extraOptions = [
            "--pull=missing"
          ];
        };
      })

      (lib.mkIf cfg.qbittorrent.enable {
        seedbox-qbittorrent = {
          image = cfg.qbittorrent.image;
          autoStart = true;
          dependsOn = [ gluetunContainerName ];
          environment = {
            PUID = toString cfg.uid;
            PGID = toString cfg.gid;
            TZ = config.time.timeZone;
            WEBUI_PORT = toString cfg.qbittorrent.webuiPort;
            TORRENTING_PORT = toString cfg.qbittorrent.torrentPort;
          };
          volumes = [
            "${cfg.dataRoot}/qbittorrent/config:/config"
            "${cfg.dataRoot}/downloads:/downloads"
          ];
          extraOptions = [
            "--network=container:${gluetunContainerName}"
            "--pull=missing"
          ];
        };
      })
    ];

    systemd.services.podman-seedbox-qbittorrent =
      lib.mkIf (cfg.gluetun.enable && cfg.qbittorrent.enable)
        {
          after = [ "podman-${gluetunContainerName}.service" ];
          requires = [ "podman-${gluetunContainerName}.service" ];
          unitConfig.ConditionPathExists = cfg.gluetun.environmentFile;
          preStart = ''
            ${pkgs.coreutils}/bin/install -d -o seedbox -g seedbox -m 0750 ${cfg.dataRoot}/qbittorrent/config/qBittorrent
            qbit_config=${cfg.dataRoot}/qbittorrent/config/qBittorrent/qBittorrent.conf
            if [ ! -e "$qbit_config" ]; then
              ${pkgs.coreutils}/bin/printf '%s\n' \
                '[Preferences]' \
                'WebUI\AuthSubnetWhitelist=10.8.0.1/32' \
                'WebUI\AuthSubnetWhitelistEnabled=true' \
                'WebUI\HostHeaderValidation=false' \
                'WebUI\ReverseProxySupportEnabled=true' \
                > "$qbit_config"
              ${pkgs.coreutils}/bin/chown seedbox:seedbox "$qbit_config"
              ${pkgs.coreutils}/bin/chmod 0640 "$qbit_config"
            fi
          '';
        };

    systemd.services."podman-${gluetunContainerName}" = lib.mkIf cfg.gluetun.enable {
      unitConfig.ConditionPathExists = cfg.gluetun.environmentFile;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.qbittorrent.enable [
      cfg.qbittorrent.webuiPort
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataRoot} 0750 seedbox seedbox - -"
      "d ${cfg.dataRoot}/downloads 0775 seedbox seedbox - -"
      "d ${cfg.dataRoot}/gluetun 0750 seedbox seedbox - -"
      "d ${cfg.dataRoot}/qbittorrent 0750 seedbox seedbox - -"
      "d ${cfg.dataRoot}/qbittorrent/config 0750 seedbox seedbox - -"
      "d /var/lib/seedbox 0750 seedbox seedbox - -"
      "d /var/lib/seedbox/gluetun 0750 seedbox seedbox - -"
    ];

    # TODO: once the real VM is audited, pin OCI image digests and migrate the
    # existing qBittorrent application data into these directories.
  };
}
