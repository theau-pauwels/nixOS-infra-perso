let
  sshPublicKeyInventory = builtins.fromJSON (builtins.readFile ./ssh-public-keys.json);
  wireguardPeers = import ./peers.nix;
in
{
  hostId = "theau-vps";
  targetHost = "theau@82.165.20.195";

  hostname = "theau-vps";
  timezone = "Europe/Brussels";
  domain = "theau-vps.duckdns.org";
  acmeEmail = "theau.pauwels@gmail.com";
  serviceDomains = {
    authelia = "authelia.theau.net";
    coolify = "coolify.theau.net";
    file = "file.theau.net";
    jellyfin = "jellyfin.theau.net";
    prowlarr = "prowlarr.theau.net";
    qbit = "qbit.theau.net";
    seer = "seer.theau.net";
    sonarr = "sonarr.theau.net";
    radarr = "radarr.theau.net";
    users = "users.theau.net";
    wg = "wg.theau.net";
    certName = "theau-net-services";
  };

  adminUser = "theau";
  adminUserHome = "/home/theau";
  publicInterface = "ens6";

  ssh = {
    port = 22;
    publicKeyInventory = sshPublicKeyInventory;
    managedAuthorizedKeys = map (entry: entry.publicKey) sshPublicKeyInventory;
  };

  firewall = {
    tcpPorts = [
      22
      80
      443
      5201
      21115
      21116
      21117
    ];
    udpPorts = [
      51820
      21116
    ];
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
    peers = builtins.filter (peer: peer.enabled or true) wireguardPeers;
    peerSkeletons = builtins.filter (peer: !(peer.enabled or true)) wireguardPeers;
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

  rustdesk = {
    enable = true;
    user = "rustdesk-server";
    dataDir = "/var/lib/rustdesk-server";
    publicHost = "theau-vps.duckdns.org";
    natTestPort = 21115;
    rendezvousPort = 21116;
    relayPort = 21117;
  };
}
