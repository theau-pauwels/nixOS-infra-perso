{ modulesPath, ... }:

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
  security.sudo.wheelNeedsPassword = false;

  personalInfra.networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      8080
    ];
  };

  personalInfra.services.seedbox = {
    enable = true;
    dataRoot = "/srv/seedbox";
    gluetun = {
      endpointIp = "82.165.20.195";
      endpointPort = 51820;
      tunnelAddress = "10.8.0.22/32";
      environmentFile = "/var/lib/seedbox/gluetun/ionos-vps2-wireguard.env";
    };
  };

  services.rpcbind.enable = false;

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

  boot.growPartition = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/srv/nas" = {
    device = "//10.1.10.124/nas";
    fsType = "cifs";
    options = [
      "guest"
      "uid=991"
      "gid=991"
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
