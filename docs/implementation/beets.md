# Beets — music metadata corrector

Runs on the VPS as a CLI tool, processes music at `/srv/nas/jellyfin/music/`.

## Setup

- Config: `/opt/theau-vps/state/beets/config.yaml`
- Database: `/var/lib/beets/musiclibrary.blb` (local, SQLite over CIFS fails)
- Music: `/srv/nas/jellyfin/music` (via `/srv/nas` CIFS mount)
- Log: `/var/log/beets.log`

## Manual usage

```bash
# Import new music
beet -c /opt/theau-vps/state/beets/config.yaml import /srv/nas/jellyfin/music/

# Stats
beet -c /opt/theau-vps/state/beets/config.yaml stats

# Fix metadata on existing files
beet -c /opt/theau-vps/state/beets/config.yaml modify artist="Correct Name"

# Query
beet -c /opt/theau-vps/state/beets/config.yaml ls artist:Beatles
```

## Lidarr integration

Lidarr can trigger beets after each import via its custom script connection.

In Lidarr UI: Settings → Connect → Custom Script → add:
- Name: Beets import
- Path: `/opt/theau-vps/state/beets/lidarr-import.sh`
- On Import: yes
- On Upgrade: yes

The script runs `beet import -q` on the newly imported album path.

## CIFS note

The SQLite database MUST be on local storage (`/var/lib/beets/`). SQLite file
locking does not work reliably over CIFS/exFAT.
