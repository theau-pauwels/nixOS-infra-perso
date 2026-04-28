{ config, lib, ... }:

let
  cfg = config.personalInfra.backup.zfs;
in
{
  options.personalInfra.backup.zfs = {
    enable = lib.mkEnableOption "safe ZFS skeleton";

    pools = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Documentation-only pool metadata for now. No auto-format.";
    };

    datasets = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Documentation-only dataset examples for future planning.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = lib.mkDefault [ "zfs" ];

    warnings = [
      "personalInfra.backup.zfs is a safe skeleton: it does not create, format, or destroy pools."
    ];

    # TODO: after disk audit, model pools and datasets explicitly. Do not add
    # auto-formatting defaults.
  };
}
