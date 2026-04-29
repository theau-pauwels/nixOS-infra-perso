# Service: Offline Wikipedia Instance

## Reference Context
See `../MASTER.md` for full infrastructure context.

Relevant expectations:
- Some services must remain available even without Internet access.
- Internal services should be LAN or VPN accessible only.
- Storage-heavy services should preferably live on NAS or Kot infrastructure.

## This Service Implements

### Objective
Deploy a local Wikipedia mirror accessible offline on the internal network to provide a searchable knowledge base without Internet connectivity.

### Target Use Cases
- Consult Wikipedia content during network outages.
- Provide a local knowledge base for LAN users.
- Use as a lightweight documentation/reference system.

### Tasks

1. **Choose implementation approach**
   Document and select one:
   - Kiwix (recommended for simplicity, ZIM files)
   - MediaWiki mirror (heavier, more complex)

2. **Create service module**
   - `modules/services/wiki-offline.nix`
   - Disabled by default.
   - Options:
     - data directory
     - ZIM file path(s)
     - HTTP bind address
     - port
     - reverse proxy integration

3. **Storage integration**
   - Prefer NAS storage for large ZIM files.
   - Document expected size (tens to hundreds of GB depending on dataset).
   - Avoid embedding data in the Nix store.

4. **Network exposure**
   - LAN-only by default.
   - Optional VPN access.
   - No public exposure.

5. **Reverse proxy integration (optional)**
   - Integrate with Caddy for friendly URLs (e.g., `wiki.internal`).
   - No Authelia required unless explicitly requested.

6. **Update workflow documentation**
   - Document how to update ZIM files periodically.
   - Manual or automated sync strategy.
   - Disk space management.

7. **Documentation**
   - `docs/implementation/wiki-offline.md`
     - Chosen approach rationale.
     - Storage requirements.
     - Update strategy.
     - Access model.
     - Limitations vs real Wikipedia.

## Constraints
- Do not attempt to fully mirror Wikipedia dynamically.
- Do not expose the service publicly.
- Do not store large datasets in the Git repository.
- Ensure service works without Internet access.

## Acceptance Criteria
- `modules/services/wiki-offline.nix` exists and is valid.
- Service can be enabled without breaking builds.
- Documentation clearly explains storage and update model.
- Service is LAN-only by default.

## Questions to Ask Before Starting
1. Do you prefer Kiwix (static ZIM) or a full MediaWiki mirror?
2. Where should the data be stored (NAS vs local disk)?
3. Should updates be automated or manual?
4. Approximate disk space budget?
