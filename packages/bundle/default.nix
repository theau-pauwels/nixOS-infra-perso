{
  lib,
  pkgs,
  hostSpec,
  wgdashboard,
}:

let
  tcpPorts = lib.concatMapStringsSep ", " toString hostSpec.firewall.tcpPorts;
  udpPorts = lib.concatMapStringsSep ", " toString hostSpec.firewall.udpPorts;
  peerEndpointAllowedIps = lib.concatStringsSep ", " hostSpec.wireguard.peerEndpointAllowedIps;
  publicPeerJson = builtins.toJSON hostSpec.wireguard.peers;
  stableAdminKeys = lib.concatStringsSep "\n" hostSpec.ssh.stableAdminAuthorizedKeys;

  sshdConfig = ''
    Port ${toString hostSpec.ssh.port}
    PermitRootLogin no
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
    AuthenticationMethods publickey
    PermitEmptyPasswords no
    UsePAM yes
    AllowUsers ${hostSpec.adminUser}
    X11Forwarding no
  '';

  sysctlConfig = ''
    net.ipv4.ip_forward = 1
    net.ipv4.conf.all.rp_filter = 1
    net.ipv4.conf.default.rp_filter = 1
  '';

  nftablesConfig = ''
    flush ruleset

    table inet filter {
      chain input {
        type filter hook input priority 0; policy drop;
        ct state invalid drop
        ct state established,related accept
        iifname "lo" accept
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        tcp dport { ${tcpPorts} } accept
        udp dport { ${udpPorts} } accept
      }

      chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        iifname "${hostSpec.wireguard.interface}" accept
        oifname "${hostSpec.wireguard.interface}" accept
      }
    }

    table ip nat {
      chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        ip saddr ${hostSpec.wireguard.subnet} oifname "${hostSpec.publicInterface}" masquerade
      }
    }
  '';

  nginxConfig = ''
    user www-data;
    worker_processes auto;
    pid /run/theau-vps/nginx.pid;

    events {
      worker_connections 1024;
    }

    http {
      include ${pkgs.nginx}/conf/mime.types;
      default_type application/octet-stream;

      access_log /var/log/theau-vps/nginx/access.log;
      error_log /var/log/theau-vps/nginx/error.log warn;

      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;
      keepalive_timeout 65;
      client_max_body_size 16m;

      client_body_temp_path /var/cache/theau-vps/nginx/client_body;
      proxy_temp_path /var/cache/theau-vps/nginx/proxy;
      fastcgi_temp_path /var/cache/theau-vps/nginx/fastcgi;
      uwsgi_temp_path /var/cache/theau-vps/nginx/uwsgi;
      scgi_temp_path /var/cache/theau-vps/nginx/scgi;

      include /etc/theau-vps/nginx/sites-enabled/*.conf;
    }
  '';

  nginxSiteHttp = ''
    server {
      listen 80;
      listen [::]:80;
      server_name ${hostSpec.domain};

      location /.well-known/acme-challenge/ {
        root /var/lib/theau-vps/acme-challenge;
      }

      location / {
        proxy_pass http://${hostSpec.wgdashboard.listenAddress}:${toString hostSpec.wgdashboard.listenPort};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
  '';

  nginxSiteHttps = ''
    server {
      listen 80;
      listen [::]:80;
      server_name ${hostSpec.domain};

      location /.well-known/acme-challenge/ {
        root /var/lib/theau-vps/acme-challenge;
      }

      location / {
        return 301 https://$host$request_uri;
      }
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name ${hostSpec.domain};

      ssl_certificate /etc/letsencrypt/live/${hostSpec.domain}/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/${hostSpec.domain}/privkey.pem;
      ssl_session_timeout 1d;
      ssl_session_cache shared:THEAUVPS:10m;
      ssl_session_tickets off;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;

      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy no-referrer-when-downgrade always;

      location /.well-known/acme-challenge/ {
        root /var/lib/theau-vps/acme-challenge;
      }

      location / {
        proxy_pass http://${hostSpec.wgdashboard.listenAddress}:${toString hostSpec.wgdashboard.listenPort};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
  '';

  wgDashboardIniTemplate = ''
    [Peers]
    remote_endpoint = ${hostSpec.domain}
    peer_global_dns = ${hostSpec.wireguard.peerDefaultDns}
    peer_endpoint_allowed_ip = ${peerEndpointAllowedIps}
    peer_display_mode = grid
    peer_mtu = ${toString hostSpec.wireguard.peerMtu}
    peer_keep_alive = ${toString hostSpec.wireguard.peerPersistentKeepalive}

    [Server]
    app_port = ${toString hostSpec.wgdashboard.listenPort}
    wg_conf_path = /etc/wireguard
    awg_conf_path = /etc/amnezia/amneziawg
    app_prefix = ${hostSpec.wgdashboard.appPrefix}
    app_ip = ${hostSpec.wgdashboard.listenAddress}
    auth_req = ${if hostSpec.wgdashboard.authRequired then "true" else "false"}
    version = v4.3.2
    dashboard_refresh_interval = 60000
    dashboard_peer_list_display = grid
    dashboard_sort = status
    dashboard_theme = ${hostSpec.wgdashboard.theme}
    dashboard_api_key = false
    dashboard_language = ${hostSpec.wgdashboard.language}

    [Account]
    username = ${hostSpec.wgdashboard.adminUser}
    password = @WGDASHBOARD_PASSWORD_HASH@
    enable_totp = false
    totp_verified = false
    totp_key = @WGDASHBOARD_TOTP_KEY@

    [Other]
    welcome_session = true

    [Database]
    type = sqlite
    host =
    port =
    username =
    password =

    [Email]
    server =
    port =
    encryption =
    username =
    email_password =
    authentication_required = true
    send_from =
    email_template =

    [OIDC]
    admin_enable = false
    client_enable = false

    [Clients]
    enable = true

    [WireGuardConfiguration]
    autostart = ${hostSpec.wireguard.interface}
  '';

  wireguardUnit = ''
    [Unit]
    Description=theau-vps WireGuard interface ${hostSpec.wireguard.interface}
    After=network-online.target theau-vps-firewall.service
    Wants=network-online.target
    Requires=theau-vps-firewall.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStartPre=${pkgs.coreutils}/bin/test -f /etc/wireguard/${hostSpec.wireguard.interface}.conf
    ExecStart=${pkgs.bash}/bin/bash -lc '${pkgs.wireguard-tools}/bin/wg-quick up /etc/wireguard/${hostSpec.wireguard.interface}.conf'
    ExecStop=${pkgs.bash}/bin/bash -lc '${pkgs.wireguard-tools}/bin/wg-quick down /etc/wireguard/${hostSpec.wireguard.interface}.conf'
    TimeoutSec=120

    [Install]
    WantedBy=multi-user.target
  '';

  wgdashboardUnit = ''
    [Unit]
    Description=theau-vps WGDashboard
    After=network-online.target theau-vps-wireguard.service
    Wants=network-online.target theau-vps-wireguard.service

    [Service]
    Type=simple
    User=root
    Group=root
    WorkingDirectory=${wgdashboard}/share/wgdashboard
    Environment=CONFIGURATION_PATH=/var/lib/wgdashboard
    ExecStartPre=${pkgs.coreutils}/bin/install -d -m 0750 /var/lib/wgdashboard /var/lib/wgdashboard/db /var/lib/wgdashboard/log /var/lib/wgdashboard/plugins /var/lib/wgdashboard/letsencrypt/work-dir /var/lib/wgdashboard/letsencrypt/config-dir
    ExecStart=${wgdashboard}/bin/wgdashboard-gunicorn
    Restart=on-failure
    RestartSec=5
    NoNewPrivileges=yes
    PrivateTmp=yes
    LimitNOFILE=65535

    [Install]
    WantedBy=multi-user.target
  '';

  firewallUnit = ''
    [Unit]
    Description=theau-vps firewall
    Before=theau-vps-wireguard.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=${pkgs.nftables}/bin/nft -f /etc/theau-vps/nftables.conf
    ExecReload=${pkgs.nftables}/bin/nft -f /etc/theau-vps/nftables.conf
    ExecStop=${pkgs.nftables}/bin/nft flush ruleset

    [Install]
    WantedBy=multi-user.target
  '';

  nginxUnit = ''
    [Unit]
    Description=theau-vps nginx
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=forking
    PIDFile=/run/theau-vps/nginx.pid
    ExecStartPre=${pkgs.coreutils}/bin/install -d -m 0755 /run/theau-vps /var/log/nginx /var/log/theau-vps/nginx /var/cache/theau-vps/nginx/client_body /var/cache/theau-vps/nginx/proxy /var/cache/theau-vps/nginx/fastcgi /var/cache/theau-vps/nginx/uwsgi /var/cache/theau-vps/nginx/scgi /var/lib/theau-vps/acme-challenge
    ExecStart=${pkgs.nginx}/bin/nginx -c /etc/theau-vps/nginx/nginx.conf
    ExecReload=${pkgs.coreutils}/bin/kill -HUP $MAINPID
    ExecStop=${pkgs.coreutils}/bin/kill -QUIT $MAINPID
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=multi-user.target
  '';

  certbotRenewService = ''
    [Unit]
    Description=Renew Let's Encrypt certificates for theau-vps
    Wants=theau-vps-nginx.service
    After=theau-vps-nginx.service

    [Service]
    Type=oneshot
    ExecStart=${pkgs.certbot}/bin/certbot renew --quiet --webroot -w /var/lib/theau-vps/acme-challenge --deploy-hook '${pkgs.systemd}/bin/systemctl reload theau-vps-nginx.service'
  '';

  certbotRenewTimer = ''
    [Unit]
    Description=Daily certificate renewal for theau-vps

    [Timer]
    OnCalendar=*-*-* 03:17:00
    RandomizedDelaySec=30m
    Persistent=true

    [Install]
    WantedBy=timers.target
  '';

  iperf3Unit = ''
    [Unit]
    Description=theau-vps iperf3 server
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    ExecStart=${pkgs.iperf3}/bin/iperf3 -s -p ${toString hostSpec.iperf3.port}
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=multi-user.target
  '';
in
pkgs.runCommand "theau-vps-bundle" { } ''
  mkdir -p "$out/bin" "$out/libexec" "$out/share/theau-vps"
  mkdir -p "$out/share/theau-vps/nginx" "$out/share/theau-vps/systemd" "$out/share/theau-vps/ssh"

  cp ${../../deploy/activate-generation.sh} "$out/bin/activate-theau-vps-generation"
  cp ${../../deploy/push-generation.sh} "$out/libexec/push-generation.sh"
  cp ${../../deploy/rollback.sh} "$out/libexec/rollback.sh"
  cp ${../../deploy/issue-certificate.sh} "$out/libexec/issue-certificate.sh"
  chmod +x "$out/bin/activate-theau-vps-generation" "$out/libexec/push-generation.sh" "$out/libexec/rollback.sh" "$out/libexec/issue-certificate.sh"

  cat > "$out/share/theau-vps/host-spec.json" <<'EOF'
  ${builtins.toJSON hostSpec}
  EOF

  cat > "$out/share/theau-vps/public-peers.json" <<'EOF'
  ${publicPeerJson}
  EOF

  cat > "$out/share/theau-vps/ssh/stable-admin-authorized-keys" <<'EOF'
  ${stableAdminKeys}
  EOF

  cat > "$out/share/theau-vps/ssh/60-theau-vps.conf" <<'EOF'
  ${sshdConfig}
  EOF

  cat > "$out/share/theau-vps/sysctl.conf" <<'EOF'
  ${sysctlConfig}
  EOF

  cat > "$out/share/theau-vps/nftables.conf" <<'EOF'
  ${nftablesConfig}
  EOF

  cat > "$out/share/theau-vps/nginx/nginx.conf" <<'EOF'
  ${nginxConfig}
  EOF

  cat > "$out/share/theau-vps/nginx/site-http.conf" <<'EOF'
  ${nginxSiteHttp}
  EOF

  cat > "$out/share/theau-vps/nginx/site-https.conf" <<'EOF'
  ${nginxSiteHttps}
  EOF

  cat > "$out/share/theau-vps/wg-dashboard.ini.template" <<'EOF'
  ${wgDashboardIniTemplate}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-firewall.service" <<'EOF'
  ${firewallUnit}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-wireguard.service" <<'EOF'
  ${wireguardUnit}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-nginx.service" <<'EOF'
  ${nginxUnit}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-wgdashboard.service" <<'EOF'
  ${wgdashboardUnit}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-certbot-renew.service" <<'EOF'
  ${certbotRenewService}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-certbot-renew.timer" <<'EOF'
  ${certbotRenewTimer}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-iperf3.service" <<'EOF'
  ${iperf3Unit}
  EOF

  ln -s ${wgdashboard} "$out/share/theau-vps/wgdashboard-package"
  ln -s ${pkgs.nginx} "$out/share/theau-vps/nginx-package"
  ln -s ${pkgs.certbot} "$out/share/theau-vps/certbot-package"
  ln -s ${pkgs.nftables} "$out/share/theau-vps/nftables-package"
  ln -s ${pkgs.wireguard-tools} "$out/share/theau-vps/wireguard-tools-package"
  ln -s ${pkgs.iperf3} "$out/share/theau-vps/iperf3-package"
  ln -s ${pkgs.systemd} "$out/share/theau-vps/systemd-package"
  ln -s ${pkgs.iproute2} "$out/share/theau-vps/iproute2-package"
  ln -s ${pkgs.openssh} "$out/share/theau-vps/openssh-package"
  ln -s ${pkgs.python3} "$out/share/theau-vps/python3-package"
  ln -s ${pkgs.coreutils} "$out/share/theau-vps/coreutils-package"
  ln -s ${pkgs.procps} "$out/share/theau-vps/procps-package"
  ln -s ${pkgs.bash} "$out/share/theau-vps/bash-package"
''
