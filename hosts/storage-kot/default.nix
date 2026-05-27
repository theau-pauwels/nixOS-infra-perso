{
  config,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/observability/exporters.nix
    ../../modules/backup/restic.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "storage-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  personalInfra.common.ssh.adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJq35mLFxKBWuUJiawrAW9Sd+e8p8KIuOOZNmXE9f+2q theau-vps deploy 2026-04-06"
  ];

  networking.networkmanager.enable = true;
  networking.defaultGateway = {
    address = "10.224.20.1";
    interface = "ens18";
  };
  networking.interfaces.ens18.ipv4.addresses = [
    { address = "10.224.20.10"; prefixLength = 24; }
  ];
  security.sudo.wheelNeedsPassword = false;

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      139
      445
      8082
    ];
    allowedUDPPorts = [
      137
      138
    ];
  };

  networking.wg-quick.interfaces.theau-vps = {
    address = [ "10.8.0.23/32" ];
    privateKeyFile = "/var/lib/wireguard/theau-vps/private-key";
    peers = [
      {
        publicKey = "Yp43qdK8PrYR+SYZ6s9dGsYkbsgLZEk4c6NTVZcETBc=";
        presharedKeyFile = "/var/lib/wireguard/theau-vps/preshared-key";
        allowedIPs = [ "10.8.0.0/24" ];
        endpoint = "82.165.20.195:51820";
        persistentKeepalive = 21;
      }
    ];
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "KOT";
        "server string" = "storage-kot";
        "security" = "user";
        "map to guest" = "Bad Password";
        "server min protocol" = "SMB3_00";
        "hosts allow" = "10.8.0.0/24 10.224.20.0/24 10.1.10.0/24 127.0.0.0/8";
        "hosts deny" = "0.0.0.0/0";
      };
      nas = {
        path = "/srv/nas";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0666";
        "directory mask" = "0777";
        "force user" = "theau";
        "force group" = "users";
      };
      jellyfin = {
        path = "/srv/nas/jellyfin";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0666";
        "directory mask" = "0777";
        "force user" = "theau";
        "force group" = "users";
      };
      downloads = {
        path = "/srv/nas/downloads";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0666";
        "directory mask" = "0777";
        "force user" = "theau";
        "force group" = "users";
      };
    };
  };

  services.samba-wsdd.enable = true;

  services.filebrowser = {
    enable = true;
    openFirewall = false;
    settings = {
      address = "10.8.0.23";
      port = 8082;
      root = "/srv/nas";
      database = "/var/lib/filebrowser/database.db";
    };
  };

  systemd.services.filebrowser.preStart = ''
    if [ -f /var/lib/filebrowser/database.db ]; then
      PATH=${pkgs.filebrowser}/bin:${pkgs.glibc}/bin:$PATH
      filebrowser config set --auth.method=proxy --auth.header=Remote-User --database /var/lib/filebrowser/database.db 2>/dev/null || true
      filebrowser users update 1 --username=theau --perm.admin=true --database /var/lib/filebrowser/database.db 2>/dev/null || true
    fi
  '';

  # Filebrowser a besoin d'ecrire dans /srv/nas (appartient a theau:users)
  users.users.filebrowser.extraGroups = [ "users" ];

  # /srv/nas — disque de donnees (migre exfat -> ext4)
  fileSystems."/srv/nas" = {
    device = "/dev/disk/by-uuid/5d45548a-3a2e-4db5-9db8-97f6a4b23902";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

  # Assurer que /srv/nas reste world-writable (exfat avait umask=000)
  systemd.services.fix-nas-permissions = {
    description = "Fix /srv/nas ownership and permissions";
    wantedBy = [ "multi-user.target" ];
    before = [ "samba-smbd.service" "filebrowser.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      chown -R theau:users /srv/nas
      chmod -R 777 /srv/nas
    '';
  };

  personalInfra.observability.exporters.enable = false;
  personalInfra.backup.restic.enable = false;

  services.qemuGuest.enable = true;
  services.fstrim.enable = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/wireguard 0700 root root - -"
    "d /var/lib/wireguard/theau-vps 0700 root root - -"
    "d /var/lib/filebrowser 0750 filebrowser filebrowser - -"
  ];

  boot.growPartition = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  system.stateVersion = "25.11";
}
