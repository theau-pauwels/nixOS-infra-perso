{ config, lib, ... }:

let
  cfg = config.personalInfra.backup.zfs;
in
{
  options.personalInfra.backup.zfs = {
    enable = lib.mkEnableOption "safe ZFS dataset and snapshot configuration";

    hostId = lib.mkOption {
      type = lib.types.str;
      default = "22400010";
      description = "Stable 8-hex-digit ZFS host id for import safety.";
    };

    pools = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            topology = lib.mkOption {
              type = lib.types.str;
              default = "raidz2";
              description = "Documented pool topology. This module never creates the pool.";
            };

            devices = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Stable by-id data partitions used by the manual zpool create procedure.";
            };
          };
        }
      );
      default = { };
      description = "Documented pool metadata. No auto-format or auto-create behavior.";
    };

    datasets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mountpoint = lib.mkOption {
              type = lib.types.str;
              description = "Dataset mountpoint.";
            };

            sanoidTemplate = lib.mkOption {
              type = lib.types.str;
              default = "nas";
              description = "Sanoid retention template name.";
            };
          };
        }
      );
      default = {
        "nas/data".mountpoint = "/srv/nas/data";
        "nas/media".mountpoint = "/srv/nas/media";
        "nas/backups".mountpoint = "/srv/nas/backups";
        "nas/snapshots".mountpoint = "/srv/nas/snapshots";
      };
      description = "Expected ZFS datasets. They must be created manually.";
    };

    sanoid.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Sanoid snapshots for declared datasets.";
    };

    sanoid.templates = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {
        nas = {
          hourly = 24;
          daily = 14;
          monthly = 6;
          yearly = 1;
          autosnap = true;
          autoprune = true;
        };
      };
      description = "Sanoid snapshot templates.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = lib.mkDefault [ "zfs" ];
    networking.hostId = lib.mkDefault cfg.hostId;

    warnings = [
      "personalInfra.backup.zfs never creates, formats, or destroys pools. Create zpool/datasets manually after disk audit."
    ];

    fileSystems = lib.mapAttrs' (
      dataset: datasetCfg:
      lib.nameValuePair datasetCfg.mountpoint {
        device = dataset;
        fsType = "zfs";
        options = [ "zfsutil" ];
      }
    ) cfg.datasets;

    services.sanoid = lib.mkIf cfg.sanoid.enable {
      enable = true;
      templates = cfg.sanoid.templates;
      datasets = lib.mapAttrs (_dataset: datasetCfg: {
        useTemplate = [ datasetCfg.sanoidTemplate ];
      }) cfg.datasets;
    };
  };
}
