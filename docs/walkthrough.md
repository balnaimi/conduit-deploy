# Walkthrough

Step-by-step guides for every scenario. Each section is self-contained.

---

## 🚀 Install (Subdomain Mode)

See [walkthrough.html#subdomain](walkthrough.html#subdomain) for the full HTML version.

A complete guide from blank server to first message:
1. Prerequisites
2. DNS Setup
3. Run the Installer (mode selection, domain, media settings)
4. Health Check
5. Create Accounts
6. Sign In & Chat

---

## 💾 Backup

See [walkthrough.html#backup](walkthrough.html#backup) for the full HTML version.

How to create backups with version pinning:
1. What's in a backup (database, media, config, TLS, secrets, pinned images)
2. Create a backup (Services → Backup)
3. Why pinned image versions matter
4. Download a copy off-server

---

## 🔄 Restore (Same Server)

See [walkthrough.html#restore](walkthrough.html#restore) for the full HTML version.

Roll back to a known good state:
1. Open the script
2. Go to Restore (Services → Restore)
3. Choose your backup
4. Confirm & wait
5. Verify with Health Check

---

## 🚚 Migrate to New Server

See [walkthrough.html#migrate](walkthrough.html#migrate) for the full HTML version.

Move everything to a different machine:
1. Backup the old server
2. Copy backup to new server
3. Update DNS to new server's IP
4. Download script on new server
5. Restore from backup
6. Verify with Health Check
7. Shut down the old server

### Migration Checklist

1. ☐ Create backup on old server
2. ☐ Copy backup file to new server (`/opt/conduit-backups/`)
3. ☐ Update DNS records to new server's IP
4. ☐ Verify DNS propagation (`dig matrix.example.com +short`)
5. ☐ Download script on new server
6. ☐ Restore from backup (Services → Restore)
7. ☐ Run Health Check — all green?
8. ☐ Test login with a Matrix client
9. ☐ Stop/uninstall old server
10. ☐ 🎉 Done!
