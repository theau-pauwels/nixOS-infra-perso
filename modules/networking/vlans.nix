{ config, lib, ... }:

let
  cfg = config.personalInfra.networking.vlans;
in
{
  options.personalInfra.networking.vlans = {
    enable = lib.mkEnableOption "VLAN skeleton";

    parentInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Physical parent interface for VLANs.";
    };

    vlans = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.int;
              description = "VLAN id.";
            };
            address = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional CIDR address for this VLAN interface.";
            };
          };
        }
      );
      default = { };
      description = "Named VLAN definitions.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.parentInterface != null;
        message = "personalInfra.networking.vlans.parentInterface must be set before enabling VLANs.";
      }
    ];

    networking.vlans = lib.mapAttrs (_name: vlan: {
      id = vlan.id;
      interface = cfg.parentInterface;
    }) cfg.vlans;

    networking.interfaces = lib.mapAttrs' (
      name: vlan:
      lib.nameValuePair name (
        lib.mkIf (vlan.address != null) {
          ipv4.addresses = [
            {
              address = builtins.elemAt (lib.splitString "/" vlan.address) 0;
              prefixLength = lib.toInt (builtins.elemAt (lib.splitString "/" vlan.address) 1);
            }
          ];
        }
      )
    ) cfg.vlans;

    # TODO: add DHCP, router advertisements, and inter-VLAN firewall policy.
  };
}
