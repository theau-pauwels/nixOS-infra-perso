{ config, lib, ... }:

let
  cfg = config.personalInfra.services.fileSharing;

  shareType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Filesystem path exported by SMB/NFS.";
      };

      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Human-readable share description.";
      };

      writable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether clients may write to this share.";
      };

      validGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Unix/Samba groups allowed to access this share.";
      };

      nfsClients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "CIDR clients allowed through NFS exports.";
      };
    };
  };

  mkSambaShare =
    _name: share:
    {
      path = share.path;
      browseable = "yes";
      "read only" = if share.writable then "no" else "yes";
      "guest ok" = "no";
      "create mask" = "0660";
      "directory mask" = "0770";
      comment = share.comment;
    }
    // lib.optionalAttrs (share.validGroups != [ ]) {
      "valid users" = lib.concatMapStringsSep " " (group: "@${group}") share.validGroups;
      "force group" = builtins.head share.validGroups;
    };

  mkNfsExport =
    _name: share:
    lib.concatMapStringsSep "\n" (
      client:
      "${share.path} ${client}(${
        if share.writable then "rw" else "ro"
      },sync,no_subtree_check,root_squash)"
    ) share.nfsClients;

  allGroups = lib.unique (lib.concatMap (share: share.validGroups) (lib.attrValues cfg.shares));
in
{
  options.personalInfra.services.fileSharing = {
    enable = lib.mkEnableOption "LAN-only SMB, NFS, and web file sharing";

    workgroup = lib.mkOption {
      type = lib.types.str;
      default = "KOT";
      description = "Samba workgroup.";
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      description = "LAN interface Samba binds to. Keep this host LAN/VPN-only.";
    };

    lanSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.224.10.0/24"
        "10.224.20.0/24"
      ];
      description = "Subnets allowed by the file sharing services.";
    };

    shares = lib.mkOption {
      type = lib.types.attrsOf shareType;
      default = { };
      description = "Declarative SMB/NFS share definitions.";
    };

    fileBrowser = {
      enable = lib.mkEnableOption "FileBrowser web access for NAS shares";

      root = lib.mkOption {
        type = lib.types.path;
        default = "/srv/nas";
        description = "Root path exposed by FileBrowser.";
      };

      address = lib.mkOption {
        type = lib.types.str;
        default = "10.224.20.10";
        description = "FileBrowser LAN listen address. Do not bind this publicly.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8082;
        description = "FileBrowser listen port.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.shares != { };
        message = "personalInfra.services.fileSharing requires at least one declared share.";
      }
    ];

    users.groups = lib.genAttrs allGroups (_: { });

    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          workgroup = cfg.workgroup;
          "server string" = "nas-kot";
          "netbios name" = "NAS-KOT";
          "security" = "user";
          "map to guest" = "Never";
          "server min protocol" = "SMB3_00";
          "client min protocol" = "SMB3_00";
          "interfaces" = "lo ${cfg.lanInterface}";
          "bind interfaces only" = "yes";
          "hosts allow" = lib.concatStringsSep " " cfg.lanSubnets;
          "hosts deny" = "0.0.0.0/0";
          "load printers" = "no";
          "printing" = "bsd";
          "disable spoolss" = "yes";
        };
      }
      // lib.mapAttrs mkSambaShare cfg.shares;
    };

    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
      interface = cfg.lanInterface;
    };

    services.nfs.server = {
      enable = true;
      exports = lib.concatStringsSep "\n" (
        lib.filter (line: line != "") (lib.mapAttrsToList mkNfsExport cfg.shares)
      );
    };

    services.filebrowser = lib.mkIf cfg.fileBrowser.enable {
      enable = true;
      openFirewall = false;
      settings = {
        address = cfg.fileBrowser.address;
        port = cfg.fileBrowser.port;
        root = cfg.fileBrowser.root;
        database = "/var/lib/filebrowser/database.db";
      };
    };

    users.users.filebrowser.extraGroups = lib.mkIf cfg.fileBrowser.enable allGroups;

    networking.firewall.allowedTCPPorts = [
      111
      2049
      5357
      cfg.fileBrowser.port
    ];
    networking.firewall.allowedUDPPorts = [
      111
      3702
    ];
  };
}
