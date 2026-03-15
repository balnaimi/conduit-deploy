# Backup & Restore

How to protect your data, restore from a backup, or migrate to a new server.

---

## Scenarios

1. [What's in a Backup](#1-whats-in-a-backup) — Everything the backup includes
2. [Create a Backup](#2-create-a-backup) — Save your current state
3. [Scenario A: Restore on Same Server](#3-scenario-a-restore-on-same-server) — Roll back or recover
4. [Scenario B: Migrate to a New Server](#4-scenario-b-migrate-to-a-new-server) — Move everything to a different machine
5. [Best Practices](#5-best-practices) — Tips and automation

---

## 1. What's in a Backup

Every backup is a single `.tar.gz` file stored in `/opt/conduit-backups/`. It includes:

| Component | What It Contains |
|-----------|-----------------|
| **Database** | All rooms, messages, user accounts, encryption keys |
| **Media files** | Uploaded images, videos, documents |
| **Configuration** | `.env`, `docker-compose.yml`, `conduit.toml`, `Caddyfile` |
| **TLS certificates** | Let's Encrypt certs and Coturn TLS files |
| **Secrets** | Registration token, TURN credentials |
| **Pinned image versions** | SHA256 digests of the exact Docker images that were running |

> **🔒 Version Pinning:** The backup saves exact Docker image versions (SHA256 digests). Restoring pulls those *exact same images* — not newer versions. Your restore is a perfect rollback.

> **📁 Storage:** Backups are in `/opt/conduit-backups/` (separate from `/opt/conduit/`). They survive uninstall and installation corruption.

---

## 2. Create a Backup

From the main menu: **`5`** (Services) → **`7`** (Backup with version pinning)

```
1. Checks disk space
2. Offers to clean up old backups (keep latest 2)
3. Saves exact Docker image versions:
   ✅ conduit → 4078e80577cc...
   ✅ caddy → fce4f15aad23...
   ✅ coturn → 229f87ef2428...
4. Creates backup archive:
   ✅ Backup saved: /opt/conduit-backups/conduit-backup-2026-03-15-180609.tar.gz
```

**When to backup:**
- Before updating containers (script offers this automatically)
- Before configuration changes
- Regularly, as part of maintenance
- Before migrating to a new server

---

## 3. Scenario A: Restore on Same Server

**Use case:** An update broke something, you want to roll back, or you accidentally deleted data.

### When Conduit is Still Installed

Main menu → **`5`** (Services) → **`8`** (Restore from backup)

```
Available backups:
  conduit-backup-2026-03-15-180609.tar.gz
  conduit-backup-2026-03-15-084550.tar.gz

Backup file path: /opt/conduit-backups/conduit-backup-2026-03-15-180609.tar.gz

⚠️ WARNING: This will replace your current installation!
Type 'RESTORE' to confirm: RESTORE
```

The restore process:
1. Stops current services
2. Extracts backup files to `/opt/conduit/`
3. Pulls the *exact same Docker images* (pinned versions)
4. Starts services
5. Verifies everything is running

```
ℹ Restoring from backup...
✅ Files restored

═══ Restoring pinned image versions ═══
  ✅ conduit
  ✅ caddy
  ✅ coturn

ℹ Starting services...
✅ Restore complete! Services are running.
```

### After Uninstall (No Installation Present)

If you uninstalled but backups remain in `/opt/conduit-backups/`:

1. Run the script — it detects "Not installed"
2. Go to **`5`** (Services) — only Restore is available
3. Choose **`8`** and select your backup

```
═══ Service Management ═══

  Conduit is not installed. Only restore is available.

  8) Restore from backup
  0) Back to main menu
```

---

## 4. Scenario B: Migrate to a New Server

**Use case:** Moving to a bigger server, switching providers, or disaster recovery.

> **⚠️ Same Domain Required:** The backup contains your domain configuration. The new server must use the *same domain*. You can't change `matrix.example.com` to `chat.example.com` during migration.

### Step 1: Create a Backup on the Old Server

Run the script → Services → Backup. Note the file path.

### Step 2: Copy the Backup to the New Server

```bash
# From your local machine:
scp root@old-server:/opt/conduit-backups/conduit-backup-*.tar.gz /tmp/

# To the new server:
ssh root@new-server "mkdir -p /opt/conduit-backups"
scp /tmp/conduit-backup-*.tar.gz root@new-server:/opt/conduit-backups/
```

Or direct transfer:
```bash
ssh root@old-server "cat /opt/conduit-backups/conduit-backup-*.tar.gz" | \
  ssh root@new-server "mkdir -p /opt/conduit-backups && cat > /opt/conduit-backups/conduit-backup.tar.gz"
```

### Step 3: Update DNS

Point your domain to the new server's IP:

| Type | Name | Old Value | New Value |
|------|------|-----------|-----------|
| `A` | `matrix` | `old-server-ip` | `new-server-ip` |
| `AAAA` | `matrix` | `old-ipv6` | `new-ipv6` |

Wait for DNS propagation.

### Step 4: Run the Script on the New Server

```bash
ssh root@new-server-ip
curl -sL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/conduit-deploy.sh | bash
```

### Step 5: Restore from Backup

The script detects no installation. Go to Services → Restore:

```
Main menu → 5 (Services)
  "Conduit is not installed. Only restore is available."
  → 8 (Restore from backup)
  → Select your backup file
  → Type 'RESTORE' to confirm

✅ Files restored
✅ conduit, caddy, coturn pulled
✅ Restore complete! Services are running.
```

### Step 6: Verify

Run Health Check (`3`) on the new server. Then stop the old one:

```bash
# On OLD server — stop to avoid split-brain:
# Run script → 5 (Services) → 2 (Stop)
# Or uninstall entirely: → 6 (Uninstall)
```

> **⚠️ Critical:** Never run two servers with the same domain simultaneously! This can corrupt your database or confuse federation.

### Step 7: TLS Certificate

Caddy automatically requests a new certificate on the new server. You don't need to do anything — just verify with Health Check.

---

## 5. Best Practices

| Practice | Why |
|----------|-----|
| **Backup before updates** | The script offers this automatically. Always say yes. |
| **Keep 2–3 backups** | Don't keep 20, but don't keep just 1. |
| **Copy backups off-server** | If the server dies, local backups die too. |
| **Test your restore** | A backup you've never tested is not a backup. |
| **Check backup size** | Sudden size changes? Investigate. |

### Automate Off-Server Copies

```bash
# Copy latest backup to another server daily at 3 AM
0 3 * * * scp /opt/conduit-backups/$(ls -t /opt/conduit-backups/ | head -1) user@backup-server:/backups/matrix/
```

### Migration Checklist

- [ ] Create backup on old server
- [ ] Copy backup to new server (`/opt/conduit-backups/`)
- [ ] Update DNS to point to new server IP
- [ ] Wait for DNS propagation
- [ ] Run script on new server → Restore
- [ ] Run Health Check — all green
- [ ] Stop or uninstall old server
- [ ] Test login from a Matrix client
- [ ] Verify messages and rooms are intact
