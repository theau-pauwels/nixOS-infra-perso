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
  serviceDomains =
    hostSpec.serviceDomains or {
      authelia = "authelia.theau.net";
      coolify = "coolify.theau.net";
      users = "users.theau.net";
      wg = "wg.theau.net";
      certName = "theau-net-services";
    };
  serviceDomainNames = [
    serviceDomains.authelia
    serviceDomains.coolify
    serviceDomains.users
    serviceDomains.wg
  ];
  serviceServerNames = lib.concatStringsSep " " serviceDomainNames;
  serviceCertPath = "/etc/letsencrypt/live/${serviceDomains.certName}/fullchain.pem";
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

      map $http_upgrade $connection_upgrade {
        default upgrade;
        "" close;
      }

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
      listen 80 default_server;
      listen [::]:80 default_server;
      server_name _;

      return 404;
    }

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

  nginxServicesHttp = ''
    server {
      listen 80;
      listen [::]:80;
      server_name ${serviceServerNames};

      location /.well-known/acme-challenge/ {
        root /var/lib/theau-vps/acme-challenge;
      }

      location / {
        return 308 https://$host$request_uri;
      }
    }
  '';

  proxyHeaders = ''
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Uri $request_uri;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  '';

  autheliaAuthLocation = ''
    location /internal/authelia/authz {
      internal;
      proxy_pass http://127.0.0.1:9091/api/authz/auth-request;
      proxy_pass_request_body off;
      proxy_set_header Content-Length "";
      proxy_set_header X-Original-Method $request_method;
      proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
      proxy_set_header X-Forwarded-Method $request_method;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-Host $http_host;
      proxy_set_header X-Forwarded-URI $request_uri;
      proxy_set_header X-Forwarded-For $remote_addr;
      proxy_set_header X-Real-IP $remote_addr;
    }
  '';

  autheliaProtectedLocation = upstream: ''
    ${autheliaAuthLocation}

    location / {
      auth_request /internal/authelia/authz;
      auth_request_set $redirection_url $upstream_http_location;
      error_page 401 =302 $redirection_url;
      auth_request_set $user $upstream_http_remote_user;
      auth_request_set $groups $upstream_http_remote_groups;
      auth_request_set $name $upstream_http_remote_name;
      auth_request_set $email $upstream_http_remote_email;
      proxy_set_header Remote-User $user;
      proxy_set_header Remote-Groups $groups;
      proxy_set_header Remote-Name $name;
      proxy_set_header Remote-Email $email;
      ${proxyHeaders}
      proxy_pass ${upstream};
    }
  '';

  nginxSiteHttps = ''
    server {
      listen 80 default_server;
      listen [::]:80 default_server;
      server_name _;

      return 404;
    }

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
      listen 443 ssl http2 default_server;
      listen [::]:443 ssl http2 default_server;
      server_name _;

      ssl_certificate /etc/letsencrypt/live/${hostSpec.domain}/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/${hostSpec.domain}/privkey.pem;
      ssl_session_timeout 1d;
      ssl_session_cache shared:THEAUVPS:10m;
      ssl_session_tickets off;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;

      return 404;
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

  nginxServicesHttps = ''
    server {
      listen 80;
      listen [::]:80;
      server_name ${serviceServerNames};

      location /.well-known/acme-challenge/ {
        root /var/lib/theau-vps/acme-challenge;
      }

      location / {
        return 308 https://$host$request_uri;
      }
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name ${serviceDomains.authelia};

      ssl_certificate /etc/letsencrypt/live/${serviceDomains.certName}/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/${serviceDomains.certName}/privkey.pem;
      ssl_session_timeout 1d;
      ssl_session_cache shared:THEAUNET:10m;
      ssl_session_tickets off;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;

      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy no-referrer-when-downgrade always;

      location / {
        ${proxyHeaders}
        proxy_pass http://127.0.0.1:9091;
      }
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name ${serviceDomains.wg};

      ssl_certificate /etc/letsencrypt/live/${serviceDomains.certName}/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/${serviceDomains.certName}/privkey.pem;
      ssl_session_timeout 1d;
      ssl_session_cache shared:THEAUNET:10m;
      ssl_session_tickets off;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;

      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy no-referrer-when-downgrade always;

      ${autheliaProtectedLocation "http://${hostSpec.wgdashboard.listenAddress}:${toString hostSpec.wgdashboard.listenPort}"}
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name ${serviceDomains.users};

      ssl_certificate /etc/letsencrypt/live/${serviceDomains.certName}/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/${serviceDomains.certName}/privkey.pem;
      ssl_session_timeout 1d;
      ssl_session_cache shared:THEAUNET:10m;
      ssl_session_tickets off;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;

      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy no-referrer-when-downgrade always;

      ${autheliaProtectedLocation "http://127.0.0.1:17170"}
    }

    server {
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
      server_name ${serviceDomains.coolify};

      ssl_certificate /etc/letsencrypt/live/${serviceDomains.certName}/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/${serviceDomains.certName}/privkey.pem;
      ssl_session_timeout 1d;
      ssl_session_cache shared:THEAUNET:10m;
      ssl_session_tickets off;
      ssl_protocols TLSv1.2 TLSv1.3;
      ssl_prefer_server_ciphers off;

      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options SAMEORIGIN always;
      add_header X-Content-Type-Options nosniff always;
      add_header Referrer-Policy no-referrer-when-downgrade always;

      ${autheliaProtectedLocation "http://127.0.0.1:8000"}
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
    Environment=WGDASHBOARD_TRUSTED_AUTH=true
    Environment=WGDASHBOARD_TRUSTED_AUTH_REQUIRED_GROUP=wg-admin
    Environment=WGDASHBOARD_TRUSTED_AUTH_ALLOWED_REMOTE_ADDRS=127.0.0.1,::1
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

  autheliaUnit = ''
    [Unit]
    Description=theau-vps Authelia
    After=network-online.target theau-vps-lldap.service
    Wants=network-online.target theau-vps-lldap.service

    [Service]
    Type=simple
    User=authelia
    Group=authelia
    WorkingDirectory=/opt/theau-vps/state/authelia
    Environment=AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE=/opt/theau-vps/state/authelia/ldap-password
    ExecStart=${pkgs.authelia}/bin/authelia --config /opt/theau-vps/state/authelia/configuration.yml
    Restart=on-failure
    RestartSec=5
    NoNewPrivileges=yes
    PrivateTmp=yes
    ProtectSystem=full
    ProtectHome=true

    [Install]
    WantedBy=multi-user.target
  '';

  lldapUnit = ''
    [Unit]
    Description=theau-vps LLDAP
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=lldap
    Group=lldap
    WorkingDirectory=/opt/theau-vps/state/lldap
    ExecStart=${pkgs.lldap}/bin/lldap run --config-file /opt/theau-vps/state/lldap/lldap_config.toml
    Restart=on-failure
    RestartSec=5
    NoNewPrivileges=yes
    PrivateTmp=yes
    ProtectSystem=full
    ProtectHome=true

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

  rustdeskHbbsUnit = ''
    [Unit]
    Description=theau-vps RustDesk hbbs rendezvous server
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    PermissionsStartOnly=true
    User=${hostSpec.rustdesk.user}
    Group=${hostSpec.rustdesk.user}
    WorkingDirectory=${hostSpec.rustdesk.dataDir}
    ExecStartPre=${pkgs.bash}/bin/bash -lc '${pkgs.coreutils}/bin/install -d -m 0750 -o ${hostSpec.rustdesk.user} -g ${hostSpec.rustdesk.user} ${hostSpec.rustdesk.dataDir}; if [[ ! -s ${hostSpec.rustdesk.dataDir}/id_ed25519 || ! -s ${hostSpec.rustdesk.dataDir}/id_ed25519.pub ]] || ! ${pkgs.rustdesk-server}/bin/rustdesk-utils validatekeypair "$(${pkgs.coreutils}/bin/cat ${hostSpec.rustdesk.dataDir}/id_ed25519.pub 2>/dev/null || true)" "$(${pkgs.coreutils}/bin/cat ${hostSpec.rustdesk.dataDir}/id_ed25519 2>/dev/null || true)" >/dev/null 2>&1; then key_output="$(${pkgs.rustdesk-server}/bin/rustdesk-utils genkeypair)"; public_key="$(echo "$key_output" | ${pkgs.gnused}/bin/sed -n "s/^Public Key:[[:space:]]*//p")"; secret_key="$(echo "$key_output" | ${pkgs.gnused}/bin/sed -n "s/^Secret Key:[[:space:]]*//p")"; echo "$secret_key" > ${hostSpec.rustdesk.dataDir}/id_ed25519; echo "$public_key" > ${hostSpec.rustdesk.dataDir}/id_ed25519.pub; fi; ${pkgs.coreutils}/bin/chown ${hostSpec.rustdesk.user}:${hostSpec.rustdesk.user} ${hostSpec.rustdesk.dataDir}/id_ed25519 ${hostSpec.rustdesk.dataDir}/id_ed25519.pub; ${pkgs.coreutils}/bin/chmod 600 ${hostSpec.rustdesk.dataDir}/id_ed25519; ${pkgs.coreutils}/bin/chmod 644 ${hostSpec.rustdesk.dataDir}/id_ed25519.pub'
    ExecStart=${pkgs.rustdesk-server}/bin/hbbs -p ${toString hostSpec.rustdesk.rendezvousPort} -r ${hostSpec.rustdesk.publicHost}:${toString hostSpec.rustdesk.relayPort}
    Restart=on-failure
    RestartSec=2
    LimitNOFILE=1048576

    [Install]
    WantedBy=multi-user.target
  '';

  rustdeskHbbrUnit = ''
    [Unit]
    Description=theau-vps RustDesk hbbr relay server
    After=network-online.target theau-vps-rustdesk-hbbs.service
    Wants=network-online.target theau-vps-rustdesk-hbbs.service

    [Service]
    Type=simple
    PermissionsStartOnly=true
    User=${hostSpec.rustdesk.user}
    Group=${hostSpec.rustdesk.user}
    WorkingDirectory=${hostSpec.rustdesk.dataDir}
    ExecStartPre=${pkgs.bash}/bin/bash -lc '${pkgs.coreutils}/bin/install -d -m 0750 -o ${hostSpec.rustdesk.user} -g ${hostSpec.rustdesk.user} ${hostSpec.rustdesk.dataDir}; if [[ ! -s ${hostSpec.rustdesk.dataDir}/id_ed25519 || ! -s ${hostSpec.rustdesk.dataDir}/id_ed25519.pub ]] || ! ${pkgs.rustdesk-server}/bin/rustdesk-utils validatekeypair "$(${pkgs.coreutils}/bin/cat ${hostSpec.rustdesk.dataDir}/id_ed25519.pub 2>/dev/null || true)" "$(${pkgs.coreutils}/bin/cat ${hostSpec.rustdesk.dataDir}/id_ed25519 2>/dev/null || true)" >/dev/null 2>&1; then key_output="$(${pkgs.rustdesk-server}/bin/rustdesk-utils genkeypair)"; public_key="$(echo "$key_output" | ${pkgs.gnused}/bin/sed -n "s/^Public Key:[[:space:]]*//p")"; secret_key="$(echo "$key_output" | ${pkgs.gnused}/bin/sed -n "s/^Secret Key:[[:space:]]*//p")"; echo "$secret_key" > ${hostSpec.rustdesk.dataDir}/id_ed25519; echo "$public_key" > ${hostSpec.rustdesk.dataDir}/id_ed25519.pub; fi; ${pkgs.coreutils}/bin/chown ${hostSpec.rustdesk.user}:${hostSpec.rustdesk.user} ${hostSpec.rustdesk.dataDir}/id_ed25519 ${hostSpec.rustdesk.dataDir}/id_ed25519.pub; ${pkgs.coreutils}/bin/chmod 600 ${hostSpec.rustdesk.dataDir}/id_ed25519; ${pkgs.coreutils}/bin/chmod 644 ${hostSpec.rustdesk.dataDir}/id_ed25519.pub'
    ExecStart=${pkgs.rustdesk-server}/bin/hbbr -p ${toString hostSpec.rustdesk.relayPort}
    Restart=on-failure
    RestartSec=2
    LimitNOFILE=1048576

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

  cat > "$out/share/theau-vps/ssh/public-key-inventory.json" <<'EOF'
  ${builtins.toJSON hostSpec.ssh.publicKeyInventory}
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

  cat > "$out/share/theau-vps/nginx/services-http.conf" <<'EOF'
  ${nginxServicesHttp}
  EOF

  cat > "$out/share/theau-vps/nginx/services-https.conf" <<'EOF'
  ${nginxServicesHttps}
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

  cat > "$out/share/theau-vps/systemd/theau-vps-authelia.service" <<'EOF'
  ${autheliaUnit}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-lldap.service" <<'EOF'
  ${lldapUnit}
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

  cat > "$out/share/theau-vps/systemd/theau-vps-rustdesk-hbbs.service" <<'EOF'
  ${rustdeskHbbsUnit}
  EOF

  cat > "$out/share/theau-vps/systemd/theau-vps-rustdesk-hbbr.service" <<'EOF'
  ${rustdeskHbbrUnit}
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
  ln -s ${pkgs.gnused} "$out/share/theau-vps/gnused-package"
  ln -s ${pkgs.rustdesk-server} "$out/share/theau-vps/rustdesk-server-package"
  ln -s ${pkgs.authelia} "$out/share/theau-vps/authelia-package"
  ln -s ${pkgs.lldap} "$out/share/theau-vps/lldap-package"
  ln -s ${pkgs.lldap-cli} "$out/share/theau-vps/lldap-cli-package"
  ln -s ${pkgs.openssl} "$out/share/theau-vps/openssl-package"
''
