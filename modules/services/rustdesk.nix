{ config, lib, pkgs, ... }:

let
  cfg = config.personalInfra.services.rustdesk;
in
{
  options.personalInfra.services.rustdesk = {
    enable = lib.mkEnableOption "RustDesk OSS server skeleton";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rustdesk-server";
      description = "Persistent RustDesk server data directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.rustdesk-server = { };
    users.users.rustdesk-server = {
      isSystemUser = true;
      group = "rustdesk-server";
      home = cfg.dataDir;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 rustdesk-server rustdesk-server - -"
    ];

    environment.systemPackages = [ pkgs.rustdesk-server ];

    # TODO: add hardened hbbs/hbbr systemd units after choosing ports and
    # persistence behavior for the native NixOS target.
  };
}
