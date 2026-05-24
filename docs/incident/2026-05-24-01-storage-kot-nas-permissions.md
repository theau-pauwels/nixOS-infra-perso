# Failure: storage-kot `/srv/nas` permissions after reboot

**Incident:** [2026-05-24 Kot Power Loss Recovery](./2026-05-24-power-loss-kot-recovery.md)

## Symptom

Samba clients (jellyfin-kot, seedbox-kot) got "Permission denied" when mounting
CIFS shares. Samba logs on storage-kot showed:

```
chdir_current_service: vfs_ChDir(/srv/nas) failed: Permission denied.
Current token: uid=1000, gid=100, 3 groups: 993 1 65534
```

## Cause

After reboot, the data disk at `/srv/nas` (ext4, UUID
`5d45548a-3a2e-4db5-9db8-97f6a4b23902`) mounted successfully but its
permissions were wrong. The `fix-nas-permissions` oneshot service is configured
with `RemainAfterExit=true`, which prevented it from re-executing after the
reboot.

```nix
systemd.services.fix-nas-permissions = {
  wantedBy = [ "multi-user.target" ];
  before = [ "samba-smbd.service" "filebrowser.service" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;   # <-- prevents re-run after reboot
  };
  script = ''
    chown -R theau:users /srv/nas
    chmod -R 777 /srv/nas
  '';
};
```

## Fix

**Immediate:** `sudo systemctl restart fix-nas-permissions` on storage-kot.

**Permanent:** Not yet applied. Options:

- Remove `RemainAfterExit = true` so the service runs on every boot.
- Alternatively, use `systemd.tmpfiles.rules` to set permissions declaratively:
  ```nix
  systemd.tmpfiles.rules = [
    "z /srv/nas 0777 theau users - -"
  ];
  ```

## Affected services

| Client | Mount | Impact |
|---|---|---|
| jellyfin-kot | `//10.1.10.124/nas` | CIFS mount failed |
| seedbox-kot | `//10.1.10.124/nas` | CIFS mount failed |
| file.theau.net | N/A | Not affected (filebrowser had its own issue) |
