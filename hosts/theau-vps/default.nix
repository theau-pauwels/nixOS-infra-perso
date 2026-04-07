{
  hostId = "theau-vps";
  targetHost = "theau@82.165.20.195";

  hostname = "theau-vps";
  timezone = "Europe/Brussels";
  domain = "theau-vps.duckdns.org";
  acmeEmail = "theau.pauwels@gmail.com";

  adminUser = "theau";
  adminUserHome = "/home/theau";
  publicInterface = "ens6";

  ssh = {
    port = 22;
    stableAdminAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKbbEgxgAKV7v3E0gbiMRJB5Ago1onGT953i8fz7xuNJ VPS-IONOS"
    ];
  };

  firewall = {
    tcpPorts = [
      22
      80
      443
      5201
    ];
    udpPorts = [ 51820 ];
  };

  wireguard = {
    interface = "wg0";
    subnet = "10.8.0.0/24";
    address = "10.8.0.1/24";
    listenPort = 51820;
    peerDefaultDns = "1.1.1.1";
    peerEndpointAllowedIps = [ "0.0.0.0/0" ];
    peerMtu = 1420;
    peerPersistentKeepalive = 21;
    peers = import ./peers.nix;
  };

  wgdashboard = {
    listenAddress = "127.0.0.1";
    listenPort = 10086;
    appPrefix = "";
    authRequired = true;
    adminUser = "admin";
    theme = "dark";
    language = "en-US";
  };

  iperf3 = {
    enable = true;
    port = 5201;
  };
}
