# Coolify PaaS

## Architecture

Coolify is modeled as a Docker Compose stack managed by
`modules/services/coolify.nix`. The module does not vendor Coolify Compose
files or secrets into Git. It expects the official runtime files to exist under
`/data/coolify/source`, matching the upstream self-hosted installation layout.

Preferred routing model:

```text
Internet -> VPS Caddy HTTPS edge -> Authelia ForwardAuth -> Coolify admin UI
Internet -> VPS Caddy/Traefik routing -> deployed app containers
```

Coolify's admin UI must be protected by Authelia or VPN. In the central
LLDAP-backed policy, access is granted to `paas-admins` and `admins`. Public
applications must be intentionally exposed per app.

## Host Placement

The module is imported on the future native NixOS VPS and disabled by default:

```nix
personalInfra.services.coolify.enable = false;
```

The first production candidate is a dedicated VM or the VPS only if resource
usage is acceptable. If Coolify runs on Kot, keep the VPS as the public Caddy
edge and route over VPN.

## Reverse Proxy Ownership

Default module mode is:

```nix
reverseProxy.mode = "caddy-edge";
reverseProxy.protectAdminWithAuthelia = true;
```

This creates a Caddy virtual host for the admin UI only. It intentionally avoids
claiming wildcard app routing until DNS and TLS ownership are decided.

Supported modes:

- `caddy-edge`: Caddy is the public edge and protects admin with Authelia.
- `traefik-internal`: Coolify/Traefik can own app routing behind the edge.
- `none`: no module-managed reverse proxy.

Do not let Caddy and Traefik both bind public `80/443` on the same host.

## DNS And TLS

Required DNS before public app exposure:

```text
coolify.theau.net -> VPS public IP
*.theau.net       -> VPS public IP, only after wildcard policy is approved
```

TLS options:

- Caddy automatic HTTPS for explicit hostnames.
- DNS-01 wildcard certificates if wildcard TLS is required.

DNS provider API tokens must be runtime secrets only. Do not assume wildcard DNS
exists yet.

## Secret Handling

Expected runtime paths:

```text
/data/coolify/source/.env
/run/secrets/coolify-app-key
/run/secrets/coolify-db-password
/run/secrets/coolify-redis-password
/run/secrets/coolify-git-token
/run/secrets/dns-provider-token
```

The `.env` file is outside Git and outside the Nix store. The module asserts
that `environmentFile` is not under `/nix/store`.

## Backup Considerations

Back up:

- `/data/coolify`
- Coolify database volume or database dump
- application deployment metadata
- Git deploy keys/tokens through the secret manager
- DNS/TLS provider token inventory

Do not configure destructive Docker volume cleanup by default.

## Test Procedure

After placing the official Coolify source files and enabling:

```bash
systemctl status docker coolify
docker compose --env-file /data/coolify/source/.env \
  -f /data/coolify/source/docker-compose.yml \
  -f /data/coolify/source/docker-compose.prod.yml ps
curl -fsSI http://127.0.0.1:8000/
```

If Caddy edge mode is enabled:

```bash
curl -fsSI https://coolify.theau.net/
```

Confirm unauthenticated access reaches Authelia, not the Coolify admin UI.

## Rollback And Troubleshooting

Rollback by disabling:

```nix
personalInfra.services.coolify.enable = false;
```

This stops the module-managed systemd unit but does not delete Docker volumes or
`/data/coolify`.

Common failures:

- missing `.env` or Compose files: Coolify unit fails before containers start
- Caddy returns 502: admin port/bind address differs from `adminBindAddress` and `adminPort`
- ACME wildcard failure: DNS-01 token or provider config missing
- app routes conflict: decide whether Caddy or Traefik owns wildcard routes before enabling both
