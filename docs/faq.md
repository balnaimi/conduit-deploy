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
- **Auto-updates** — Security patches install automatically

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

```bash
# Stop services
cd /opt/conduit && sudo docker compose down

# Back up everything
sudo tar -czf conduit-backup-$(date +%Y%m%d).tar.gz /opt/conduit /var/lib/docker/volumes/conduit_conduit-data

# Start again
sudo docker compose up -d
```

### How do I update?

Use the script menu:
```bash
sudo bash install.sh
# Choose 5 → 5 (Update containers)
```

Or manually:
```bash
cd /opt/conduit
sudo docker compose pull
sudo docker compose up -d
```

---

## Problems?

Check the [Troubleshooting](troubleshooting.md) guide.
