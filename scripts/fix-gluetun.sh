#!/bin/bash
set -e

echo "=== Restoring VPS WireGuard env file ==="
cat > /var/lib/seedbox/gluetun/ionos-vps2-wireguard.env << 'EOF'
WIREGUARD_PRIVATE_KEY=OKX9DnsREKisY0AJaT95cT55irGY+fTsVkNbRNE+9nc=
WIREGUARD_PRESHARED_KEY=muQbQ2eT0kRsppq3hoQGKQ3U7p2z/SepRtXOwXF+yV4=
WIREGUARD_PUBLIC_KEY=Yp43qdK8PrYR+SYZ6s9dGsYkbsgLZEk4c6NTVZcETBc=
EOF

echo "=== Stopping old ==="
systemctl stop podman-seedbox-gluetun podman-seedbox-qbittorrent 2>/dev/null || true
/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman rm -f seedbox-gluetun seedbox-qbittorrent 2>/dev/null || true

echo "=== Writing unit ==="
cat > /run/systemd/system/podman-seedbox-gluetun.service << 'ENDUNIT'
[Unit]
After=network-online.target
Wants=network-online.target
[Service]
User=root
Delegate=true
Restart=on-failure
TimeoutStartSec=0
TimeoutStopSec=120
Environment=VPN_SERVICE_PROVIDER=custom
Environment=VPN_TYPE=wireguard
Environment=WIREGUARD_ENDPOINT_IP=82.165.20.195
Environment=WIREGUARD_ENDPOINT_PORT=51820
Environment=WIREGUARD_ADDRESSES=10.8.0.22/32
Environment=FIREWALL=on
Environment=FIREWALL_VPN_INPUT_PORTS=8080,6881
Environment=FIREWALL_OUTBOUND_SUBNETS=10.224.20.0/24
Environment=TZ=Europe/Brussels
ExecStartPre=-/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman rm -f seedbox-gluetun
ExecStart=/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman run --name seedbox-gluetun --cap-add NET_ADMIN --device /dev/net/tun:/dev/net/tun -e VPN_SERVICE_PROVIDER -e VPN_TYPE -e WIREGUARD_ENDPOINT_IP -e WIREGUARD_ENDPOINT_PORT -e WIREGUARD_ADDRESSES -e FIREWALL -e FIREWALL_VPN_INPUT_PORTS -e FIREWALL_OUTBOUND_SUBNETS -e TZ --env-file /var/lib/seedbox/gluetun/ionos-vps2-wireguard.env -p 8080:8080 -p 6881:6881 -p 6881:6881/udp -v /srv/seedbox/gluetun:/gluetun docker.io/qmcgaw/gluetun:latest
ExecStop=/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman stop seedbox-gluetun
ExecStopPost=/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman rm -f seedbox-gluetun
ENDUNIT

echo "=== Starting ==="
systemctl daemon-reload
systemctl start podman-seedbox-gluetun
sleep 15
systemctl status podman-seedbox-gluetun 2>&1 | head -6
echo "---"
/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman logs --tail 5 seedbox-gluetun 2>&1
echo "---"
/nix/store/5g8jkidj1vixsfas10s0syykq514rmhx-podman-5.8.1/bin/podman ps --filter name=gluetun 2>&1
