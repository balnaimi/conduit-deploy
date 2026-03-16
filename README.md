# 🏠 Conduit Deploy

> Deploy your own private Matrix messaging server in minutes.

<p align="center">
  <a href="https://balnaimi.github.io/conduit-deploy/"><strong>🌐 Visit the Website</strong></a>
</p>

One interactive script that sets up a complete, secure Matrix server with **end-to-end encryption**, **voice/video calls**, and **federation**.

> **📝 Personal Project** — I built this for myself and my friends as a learning project, covering the scenarios we needed. It may not fit every use case, but you're welcome to fork it and adapt it to yours.

<p align="center">
  <img src="https://img.shields.io/badge/Matrix-Conduit-6c63ff?style=for-the-badge" alt="Matrix Conduit">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
  <img src="https://img.shields.io/badge/Debian_13-Tested-blue?style=for-the-badge" alt="Debian 13">
  <img src="https://img.shields.io/badge/Rust-Lightweight-orange?style=for-the-badge" alt="Rust">
</p>

## ✨ What You Get

| | |
|---|---|
| 🔒 **End-to-End Encryption** | Nobody can read your messages — not even the server |
| 📞 **Voice & Video Calls** | Built-in TURN/STUN that works across networks |
| 🌐 **Federation** | Talk to anyone on the Matrix network |
| 🔐 **Auto TLS** | Let's Encrypt via Caddy — zero maintenance |
| 🛡️ **Hardened** | Firewall, fail2ban, OS security patches — all automatic |
| ⚡ **Lightweight** | ~50MB RAM — runs on a $5/month VPS |

## 🚀 Quick Start

```bash
ssh user@your-server
curl -fsSL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/conduit-deploy.sh -o conduit-deploy.sh
sudo bash conduit-deploy.sh
```

That's it. The interactive menu guides you through everything.

## 📖 Documentation

| Guide | Description |
|-------|------------|
| **[Getting Started](docs/getting-started.md)** | New here? Start with this |
| **[Domain Setup](docs/domain-setup.md)** | How to set up your domain (explained simply) |
| **[Installation](docs/installation.md)** | Step-by-step installation walkthrough |
| **[After Install](docs/after-install.md)** | Set up your phone, invite people, secure things |
| **[FAQ](docs/faq.md)** | Common questions answered |
| **[Troubleshooting](docs/troubleshooting.md)** | Something not working? Check here |
| **[Roadmap](TODO.md)** | Future improvements and ideas |

### Advanced

| Guide | Description |
|-------|------------|
| [Federation](docs/advanced/federation.md) | How server-to-server communication works |
| [Voice & Video](docs/advanced/turn-calls.md) | TURN/STUN configuration details |
| [Security](docs/advanced/security.md) | What's secured and how |

## 🌐 Domain Modes

Choose how your usernames look:

| Mode | Username | Setup |
|------|----------|-------|
| **Clean** (delegation) | `@user:example.com` | 2 DNS records + .well-known (auto) |
| **Simple** (subdomain) | `@user:chat.example.com` | 1 DNS record, done |

> ⚠️ Your server name is **permanent** — choose carefully!

See [Domain Setup](docs/domain-setup.md) for full details.

## 🏗️ Architecture

```
Internet → Caddy (:80/:443/:8448) → Conduit (:6167, internal only)
           Coturn (:3478/:5349, host network)

🔒 Firewall  🛡️ Fail2ban  📜 OS Security Patches  🔄 Cert auto-renewal
```

Conduit has **no port mapping** — only accessible through Caddy's Docker network.

## 📱 Compatible Apps

| App | Platform |
|-----|----------|
| [Element](https://element.io/) | iOS / Android / Web / Desktop |
| [SchildiChat](https://schildi.chat/) | iOS / Android / Desktop |
| [FluffyChat](https://fluffychat.im/) | iOS / Android |

## 📋 Requirements

- **Server:** Debian 13 — tested on 1 GB RAM, 1 CPU, 25 GB SSD (DigitalOcean $6/mo). Not tested on other OS or specs.
- **Domain:** Any provider
- **Access:** Root or sudo
- **Time:** ~5 minutes (plus DNS propagation)

## 📦 What Gets Installed

The script automatically installs missing dependencies. Here's exactly what it adds:

| Package | Purpose |
|---------|---------|
| **Docker** | Container runtime for Conduit, Caddy, Coturn |
| **UFW** | Firewall (opens only ports 80, 443, 8448, 3478, 5349) |
| **Fail2ban** | Blocks brute-force login attempts |
| **unattended-upgrades** | Automatic OS security patches |
| **iptables-persistent** | Persists firewall rules across reboots |
| curl, openssl, dnsutils, iproute2, tar, procps, gawk | System utilities for checks, backups, and config |

> Most utilities are already on a fresh Debian install. The script checks each one and only installs what's missing.

## 💾 Backup & Restore

The script creates **complete backups** including Docker volume data (database, media, TLS certificates):

| What's Saved | Details |
|---|---|
| **Database** | All rooms, messages, accounts, encryption keys (from Docker volume) |
| **Media** | User uploads, images, videos, documents (optional — you can exclude to save space) |
| **Configuration** | `.env`, `docker-compose.yml`, `conduit.toml`, `Caddyfile`, `turnserver.conf` |
| **TLS Certificates** | Let's Encrypt certs and Caddy data (from Docker volume) |
| **Secrets** | Registration token, TURN secret |
| **Pinned Image Versions** | SHA256 digests of the exact Docker images running at backup time |

### Media: Include or Exclude

The backup will show you the size of your media files and ask whether to include them:

- **With media**: Full backup — everything restored exactly as it was
- **Without media**: Much smaller backup — accounts, messages, and config are saved, but uploaded files (images, videos, documents) are excluded. File names `-no-media` suffix.

### Why Pinned Image Versions?

When you restore, the script pulls the **exact same Docker images** (by SHA256 digest) that were running when the backup was taken:

- ✅ No surprise breaking changes from a newer version
- ✅ Database format matches the software version
- ✅ You can update later on your own terms

> **After restoring**, your server isn't locked to the old versions. Run **Services → Update containers** anytime to pull the latest. The pinning only applies during the restore itself — to give you a known-good starting point.

### Backup & Restore from the menu:

```
Services → Backup (with version pinning)    # Create a backup
Services → Restore from backup              # Restore on same or new server
```

Backups are stored separately at `/opt/conduit-backups/` — they survive uninstall and are never mixed with your live installation.

### What Restore Does

Restore is a **complete recovery** — it handles everything, even after a full uninstall:

- ✅ Extracts config files and imports database + certificates into Docker volumes
- ✅ Pulls pinned Docker images (exact versions from backup time)
- ✅ Re-creates firewall rules (UFW ports for HTTP, HTTPS, Federation, TURN)
- ✅ Re-creates TLS cert auto-sync (systemd watcher)
- ✅ Re-adds iptables UDP redirect for TURN-over-TLS

> 📖 Full walkthrough with screenshots: [Backup & Restore Guide](https://balnaimi.github.io/conduit-deploy/walkthrough.html#backup)

## 🖥️ Tested Environment

This project was built and tested on a specific setup. It hasn't been tested on other operating systems or VPS providers:

| Component | Details |
|---|---|
| **VPS Provider** | [DigitalOcean](https://www.digitalocean.com/) (Droplet) |
| **Droplet Type** | Shared CPU — Basic |
| **CPU/Disk** | Regular SSD |
| **Plan** | $6/mo — 1 GB RAM, 1 CPU, 25 GB Disk, 1000 GB transfer |
| **OS** | Debian 13 (Trixie) 64-bit |

> **Note:** I have no affiliation with DigitalOcean — I've just been using their service for a long time and it works well for me.

> **Not tested on:** Other Linux distributions, other VPS providers, ARM architectures, or different hardware specs. The script may work on similar Debian-based systems, but your mileage may vary.

## ⚠️ Disclaimer

This is a **personal project** built for my own use and for friends. It's also a learning project — I built it to understand how Matrix servers, Docker, TLS, and server administration work together.

- ✅ It covers the scenarios **I** needed
- ✅ You're free to use, fork, and modify it (MIT license)
- ⚠️ It may not cover every edge case or environment
- ⚠️ No warranty — use at your own risk
- 🤝 Pull requests and suggestions are welcome

## License

MIT — Use it, share it, modify it.

## Credits

Built with ❤️ using [Conduit](https://conduit.rs/), [Caddy](https://caddyserver.com/), and [Coturn](https://github.com/coturn/coturn).
