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
    hostName = "jellyfin-kot";
  };

  personalInfra.common.security.enable = true;
  personalInfra.common.ssh.enable = true;

  personalInfra.common.ssh.adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJq35mLFxKBWuUJiawrAW9Sd+e8p8KIuOOZNmXE9f+2q theau-vps deploy 2026-04-06"
  ];

  networking.networkmanager.enable = true;
  security.sudo.wheelNeedsPassword = false;

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      8096
    ];
  };

  networking.wg-quick.interfaces.theau-vps = {
    address = [ "10.8.0.21/32" ];
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

  # Quadro P400 passthrough from Proxmox for Jellyfin NVENC/NVDEC.
  # Pascal GPUs require the proprietary kernel module, not NVIDIA's open module.
  nixpkgs.config.allowUnfree = true;

  boot.blacklistedKernelModules = [ "nouveau" ];
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

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = false;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/srv/jellyfin/data";
    configDir = "/srv/jellyfin/config";
    cacheDir = "/srv/jellyfin/cache";
    logDir = "/srv/jellyfin/log";
  };

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils
    pciutils
  ];

  personalInfra.observability.exporters.enable = false;
  personalInfra.backup.restic.enable = false;

  services.qemuGuest.enable = true;
  services.fstrim.enable = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/wireguard 0700 root root - -"
    "d /var/lib/wireguard/theau-vps 0700 root root - -"
  ];

  boot.growPartition = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/srv/jellyfin/media" = {
    device = "//10.224.20.10/jellyfin";
    fsType = "cifs";
    options = [
      "guest"
      "uid=1000"
      "gid=1000"
      "file_mode=0664"
      "dir_mode=0775"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "cache=loose"
      "actimeo=3"
      "noacl"
      "noserverino"
      "rsize=4194304"
      "wsize=4194304"
      "vers=3.1.1"
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
