# 🏠 Conduit Deploy

> ⚠️ **Early Preview** — This project is under active development and live testing. The script is functional but has not been fully validated across all environments yet. **Not recommended for production use at this time.** A stable release is coming soon.

> Deploy your own private Matrix messaging server in minutes.

<p align="center">
  <a href="https://balnaimi.github.io/conduit-deploy/"><strong>🌐 Visit the Website</strong></a>
</p>

One interactive script that sets up a complete, secure Matrix server with **end-to-end encryption**, **voice/video calls**, and **federation** — on any Debian/Ubuntu machine.

<p align="center">
  <img src="https://img.shields.io/badge/Status-Early_Preview-orange?style=for-the-badge" alt="Early Preview">
  <img src="https://img.shields.io/badge/Matrix-Conduit-6c63ff?style=for-the-badge" alt="Matrix Conduit">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
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
| **Clean** (delegation) | `@user:example.com` | 2-3 DNS records + .well-known |
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

- **Server:** Debian 13 or Ubuntu 22.04+ (512MB RAM, 10GB disk)
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

> Most utilities are already on a fresh Debian/Ubuntu install. The script checks each one and only installs what's missing.

## License

MIT — Use it, share it, modify it.

## Credits

Built with ❤️ using [Conduit](https://conduit.rs/), [Caddy](https://caddyserver.com/), and [Coturn](https://github.com/coturn/coturn).
