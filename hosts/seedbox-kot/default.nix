{ modulesPath, pkgs, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/common/base.nix
    ../../modules/common/ssh.nix
    ../../modules/common/security.nix
    ../../modules/networking/firewall.nix
    ../../modules/services/prowlarr.nix
    ../../modules/services/seedbox.nix
    ../../modules/observability/exporters.nix
    ../../modules/backup/restic.nix
  ];

  personalInfra.common.base = {
    enable = true;
    hostName = "seedbox-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  personalInfra.common.ssh.adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJq35mLFxKBWuUJiawrAW9Sd+e8p8KIuOOZNmXE9f+2q theau-vps deploy 2026-04-06"
  ];

  networking.networkmanager.enable = true;
  networking.nameservers = [ "10.224.20.1" ];
  security.sudo.wheelNeedsPassword = false;

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      8080
      8082
    ];
  };

  personalInfra.services.seedbox = {
    enable = true;
    dataRoot = "/srv/seedbox";
    gluetun = {
      endpointIp = "86.106.84.164";
      endpointPort = 47107;
      tunnelAddress = "10.135.156.202/32";
      environmentFile = "/var/lib/seedbox/gluetun/airvpn-ipv4.env";
    };
  };

  services.rpcbind.enable = false;

  services.filebrowser = {
    enable = true;
    openFirewall = false;
    settings = {
      address = "0.0.0.0";
      port = 8082;
      root = "/srv/nas";
      database = "/var/lib/filebrowser/database.db";
    };
  };

  # Migrated database from storage-kot — switch from proxy auth to noauth for LAN access.
  systemd.services.filebrowser.preStart = ''
    if [ -f /var/lib/filebrowser/database.db ]; then
      PATH=${pkgs.filebrowser}/bin:$PATH
      filebrowser config set --auth.method=noauth --database /var/lib/filebrowser/database.db 2>/dev/null || true
      filebrowser users update 1 --username=theau --perm.admin=true --database /var/lib/filebrowser/database.db 2>/dev/null || true
    fi
  '';

  users.users.filebrowser.extraGroups = [ "users" ];

  personalInfra.services.prowlarr.enable = false;
  personalInfra.observability.exporters.enable = false;
  personalInfra.backup.restic.enable = false;

  boot.initrd.availableKernelModules = [
    "uhci_hcd"
    "ehci_pci"
    "ahci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  services.qemuGuest.enable = true;
  services.fstrim.enable = true;

  systemd.services.fix-nas-perms = {
    description = "Fix /srv/nas permissions";
    after = [ "srv-nas.mount" ];
    requires = [ "srv-nas.mount" ];
    serviceConfig.Type = "oneshot";
    script = ''
      chmod -R 0777 /srv/nas
    '';
  };

  systemd.timers.fix-nas-perms = {
    description = "Fix /srv/nas permissions every hour";
    timerConfig.OnCalendar = "hourly";
    wantedBy = [ "timers.target" ];
  };

  boot.growPartition = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/srv/nas" = {
    device = "//10.224.20.10/nas";
    fsType = "cifs";
    options = [
      "guest"
      "uid=991"
      "gid=991"
      "forceuid"
      "forcegid"
      "file_mode=0664"
      "dir_mode=0775"
      "noperm"
      "hard"
      "rsize=1048576"
      "wsize=1048576"
      "echo_interval=15"
      "actimeo=1"
      "nofail"
      "_netdev"
      "x-systemd.requires=network-online.target"
    ];
  };

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
