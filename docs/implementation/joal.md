# JOAL — Torrent Ratio Booster on the VPS

## Context

JOAL (Jack of All Trades) is a torrent ratio booster that emulates BitTorrent
clients to maintain ratios on private trackers. It runs on the VPS
(`IONOS-VPS2` / `82.165.20.195`) and watches torrent files on the storage-kot
NAS share.

## Design

- **Runtime**: Docker container using `anthonyraymond/joal:latest` (v2.1.37)
- **Network**: `--network host` for direct internet access (IP detection + DNS)
- **DNS**: `--dns 1.1.1.1` (Cloudflare) — Docker bridge DNS is unreliable after nftables flush
- **Port**: `127.0.0.1:8080` — only accessible via nginx reverse proxy
- **Config**: `/opt/theau-vps/state/joal/` (persistent across deployments)
- **Torrents**: `/mnt/storage-kot-nas/torrents/joal/` → `seedbox-kot:/srv/nas/torrents/joal/`
- **UI**: `https://joal.theau.net/joal-vps/ui/` behind Authelia (qbit-admin + admins, two-factor)

## Patches applied to the JAR

The standard JOAL distribution has two issues that required patching:

### 1. WebSocket STOMP endpoint blocked by Spring Security

JOAL's `WebSecurityConfig` uses `.anyRequest().denyAll()`, which blocks the
STOMP WebSocket handshake at `/joal-vps`. The fix adds a custom
`SecurityFilterChain` (highest priority) that permits all requests to
`/joal-vps/**`.

See: `packages/joal/StompPermitConfig.java`

### 2. Hardcoded port 80 in WebSocket URL

JOAL's JavaScript uses `port: window.location.port || "80"`, which produces
`wss://joal.theau.net:80/joal-vps` — an invalid URL for HTTPS. The fix
replaces `"80"` with a protocol-aware expression that returns `"443"` for
HTTPS and `"80"` for HTTP.

### Building the patched JAR

```bash
# 1. Extract JOAL jar
cd /tmp && mkdir joal-patch && cd joal-patch
unzip -q /path/to/jack-of-all-trades-2.1.37.jar "BOOT-INF/classes/public/static/js/main.*.chunk.js"

# 2. Fix the hardcoded port in JavaScript
JSFILE=$(ls BOOT-INF/classes/public/static/js/main.*.chunk.js)
sed -i 's/||"80"/||window.location.protocol==="https:"?"443":"80"/g' "$JSFILE"

# 3. Compile StompPermitConfig
javac -source 11 -target 11 -cp /path/to/joal.jar -d BOOT-INF/classes \
  packages/joal/StompPermitConfig.java

# 4. Inject patched files back into the JAR
cp /path/to/original.jar joal-patched.jar
chmod u+w joal-patched.jar
zip -q joal-patched.jar "$JSFILE" \
  BOOT-INF/classes/org/araymond/joal/web/config/security/StompPermitConfig.class

# 5. Deploy to VPS
scp joal-patched.jar IONOS-VPS2:/opt/joal-patched.jar
```

## Nginx configuration

The `joal.theau.net` server block provides three route types:

```
# Root redirect
location = /             → 302 /joal-vps/ui/

# WebSocket — bypass Authelia, upgrade headers
location = /joal-vps     → proxy to 127.0.0.1:8080, WebSocket upgrade

# UI + API — Authelia-protected
location /               → auth_request, proxy to 127.0.0.1:8080
```

The WebSocket path bypasses Authelia because JOAL uses its own
`secret-token` (`1234`) for STOMP authentication. The UI remains behind
Authelia with `two_factor` policy for `qbit-admin` and `admins` groups.

## Authelia access control

```yaml
access_control:
  rules:
    - domain: joal.theau.net
      policy: two_factor
      subject:
        - group:qbit-admin
        - group:admins
```

## CIFS mount for torrent files

JOAL watches torrents on the storage-kot NAS via a CIFS mount:

```
//10.8.0.23/nas  →  /mnt/storage-kot-nas  (cifs, guest, noperm)
```

The torrent directory (`torrents/joal/`) is bind-mounted into the Docker
container as `/data/torrents`. Torrent files placed in this directory (by
qBittorrent's "export finished torrents" feature) are automatically picked
up by JOAL.

## Important paths on the VPS

| Path | Purpose |
|---|---|
| `/opt/theau-vps/state/joal/` | JOAL config, clients, DB |
| `/opt/joal-patched.jar` | Patched JAR (symlinked into container) |
| `/mnt/storage-kot-nas/` | CIFS mount to storage-kot NAS |
| `/mnt/storage-kot-nas/torrents/joal/` | Torrent watch directory |

## Operations

### Check status

```bash
ssh IONOS-VPS2
sudo systemctl status theau-vps-joal
sudo docker logs joal --tail 20
```

### Restart

```bash
ssh IONOS-VPS2
sudo systemctl restart theau-vps-joal
```

### Rebuild patched JAR after JOAL update

If the JOAL Docker image is updated, the patched JAR must be rebuilt.
Download the new JAR from the container:

```bash
docker run --rm anthonyraymond/joal:latest cat /joal/joal.jar > joal-updated.jar
```

Then follow the patching steps above.

### Rollback

If the patched JAR causes issues, restore the original:

```bash
ssh IONOS-VPS2
sudo cp /path/to/original-joal.jar /opt/joal-patched.jar
sudo systemctl restart theau-vps-joal
```

The original JAR is available inside the Docker image at `/joal/joal.jar`.
