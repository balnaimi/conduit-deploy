# ❓ Frequently Asked Questions

## General

### What is Matrix?

Matrix is an **open standard** for messaging — like email but for chat. Just like you can email anyone regardless of their email provider, Matrix lets you message anyone on any Matrix server.

### Why would I run my own server?

| Reason | Explanation |
|--------|------------|
| **Privacy** | Your messages are on YOUR server, not Google's or Meta's |
| **Control** | You decide who can join, the rules, and the data retention |
| **No censorship** | Nobody can shut down your server or ban your account |
| **No ads** | Ever |
| **Family/team** | Perfect private space for family, friends, or small teams |

### Is it really free?

The software is 100% free. You only pay for:
- A server (~$5/month, or free with Oracle Cloud)
- A domain name (~$10/year)

### Is it secure?

**Yes.** Multiple layers:
- **End-to-end encryption** — Messages are encrypted on your device. Nobody (not even the server) can read them
- **TLS/HTTPS** — All traffic is encrypted in transit
- **Firewall** — Only necessary ports are open
- **Fail2ban** — Blocks brute-force attacks
- **OS security patches** — Installed automatically (no auto-reboot — you decide when to restart)

### Can I message people on other servers?

**Yes!** That's called **federation**. You can message anyone on matrix.org or any other Matrix server. It works like email — you don't need a Gmail account to email someone on Gmail.

### How is this different from WhatsApp/Telegram/Signal?

| Feature | WhatsApp | Telegram | Signal | **Your Matrix Server** |
|---------|----------|----------|--------|----------------------|
| You own the data | ❌ | ❌ | ❌ | ✅ |
| End-to-end encrypted | ✅ | ❌ (opt-in) | ✅ | ✅ |
| Open source | ❌ | Partial | ✅ | ✅ |
| Requires phone number | ✅ | ✅ | ✅ | ❌ |
| Can be shut down | ✅ | ✅ | ✅ | ❌ |
| Federation | ❌ | ❌ | ❌ | ✅ |
| Self-hostable | ❌ | ❌ | ❌ | ✅ |

---

## Technical

### What is Conduit?

Conduit is a Matrix **homeserver** written in Rust. It's lightweight and fast — perfect for small servers. It uses much less RAM than the reference implementation (Synapse).

### Why Conduit and not Synapse?

| | Conduit | Synapse |
|---|---------|---------|
| Language | Rust | Python |
| RAM usage | ~50MB | ~500MB+ |
| Setup | Simple | Complex |
| Best for | Small/medium servers | Large servers |

### Can I change the server name later?

**No.** Your server name (the part after `:` in usernames) is permanent. This is a Matrix protocol limitation, not a Conduit limitation. Choose carefully!

### How many users can it handle?

Conduit can easily handle **hundreds of users** on a small VPS. For a family or small team (5-50 people), even the cheapest VPS is more than enough.

**Real-world example:** A family of 5 people sending ~100 messages/day, with a few voice calls per week, will use less than 100 MB of RAM. The default 1 GB RAM VPS has plenty of headroom.

### What ports does it use?

| Port | What it's for |
|------|--------------|
| 80 | HTTP (redirects to HTTPS) |
| 443 | HTTPS (main traffic) |
| 8448 | Federation (server-to-server) |
| 3478 | TURN/STUN (voice/video calls) |
| 5349 | TURN over TLS |

### Where is my data stored?

Everything is in `/opt/conduit/`:
- Messages and accounts: Docker volume `conduit-data`
- Configuration: `.env`, `docker-compose.yml`, `Caddyfile`
- TLS certificates: Managed by Caddy automatically

### How do I back up?

The easiest way is through the script:
```bash
sudo bash conduit-deploy.sh
# Choose: Services → Backup (with version pinning)
```

This saves everything to `/opt/conduit-backups/` — a **separate folder** from the installation at `/opt/conduit/`. Your backups are safe even if the installation is damaged or uninstalled.

The backup exports Docker volume data (database, media, TLS certificates) and includes config files and **pinned Docker image versions** (SHA256 digests). This means restoring gives you back the exact same software, not a newer version.

You can choose to **exclude media files** (user uploads, images, videos) for a much smaller backup. Accounts and messages are always saved regardless. Backups without media have a `-no-media` suffix in the filename.

> **After restoring**, you're not locked to the old versions. Run **Services → Update containers** to pull the latest anytime. The pinning just ensures a safe starting point — after that, your server works normally.

```
/opt/
├── conduit/              ← installation
└── conduit-backups/      ← backups (separate, survives uninstall)
```

The script automatically offers to clean up old backups when you have 3 or more.

### How do I update?

Use the script menu:
```bash
sudo bash conduit-deploy.sh
# Choose 4 (Services) → 6 (Check for updates) — see what's available first
# Choose 4 (Services) → 5 (Update containers) — pull and restart
```

The script will:
1. Offer to create a backup first (recommended)
2. Pull new images
3. Restart containers
4. **Verify all 3 services are running** after the update

> **Is my data safe during updates?** Yes! Updates only replace the software (Docker images). Your data — messages, accounts, encryption keys, and uploaded files — is stored in Docker volumes, which are never touched during updates.

Or manually:
```bash
cd /opt/conduit
sudo docker compose pull
sudo docker compose up -d
```

### Why firewalld? What if I have UFW?

The script uses **firewalld** because it handles both regular port rules and NAT forwarding in one place. If your server already has UFW or iptables-persistent installed, the script **automatically removes them** before installing firewalld to avoid conflicts.

### How is the UDP 443 → 5349 redirect managed?

The script uses firewalld's `--add-forward-port` rule — a single command that persists across reboots automatically. No separate systemd service or iptables workarounds needed.

You can check the rule with:
```bash
sudo firewall-cmd --list-forward-ports
```

---

## Problems?

Check the [Troubleshooting](troubleshooting.md) guide.
