{ config, lib, ... }:

let
  cfg = config.personalInfra.networking.wireguardSite;
in
{
  options.personalInfra.networking.wireguardSite = {
    enable = lib.mkEnableOption "site-to-site WireGuard skeleton";

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "wg-site0";
      description = "WireGuard interface name for future site tunnels.";
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a WireGuard private key file outside the Nix store.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Future peer definitions. Use public keys only here.";
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
      privateKeyFile = cfg.privateKeyFile;
      peers = cfg.peers;
    };

    # TODO: add explicit routes and firewall policy per site.
  };
}
