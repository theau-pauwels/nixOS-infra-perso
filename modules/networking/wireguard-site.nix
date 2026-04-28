{ config, lib, ... }:

let
  cfg = config.personalInfra.networking.wireguardSite;
in
{
  options.personalInfra.networking.wireguardSite = {
    enable = lib.mkEnableOption "site-to-site WireGuard";

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "wg-site0";
      description = "WireGuard interface name for future site tunnels.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard interface address in CIDR notation.";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a WireGuard private key file outside the Nix store.";
    };

    listenPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Optional local WireGuard listen port.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "WireGuard peer definitions. Use public keys only here.";
    };

    routedSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Local subnets routed through this edge.";
    };

    enableForwarding = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable IPv4 forwarding for site routing.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.privateKeyFile != null;
        message = "personalInfra.networking.wireguardSite.privateKeyFile must be set outside the Nix store.";
      }
    ];

    networking.wireguard.interfaces.${cfg.interfaceName} = {
      ips = [ cfg.address ];
      privateKeyFile = cfg.privateKeyFile;
      peers = cfg.peers;
    }
    // lib.optionalAttrs (cfg.listenPort != null) { inherit (cfg) listenPort; };

    boot.kernel.sysctl = lib.mkIf cfg.enableForwarding {
      "net.ipv4.ip_forward" = 1;
    };
  };
}
