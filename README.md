# 🏠 Conduit Deploy

> Deploy your own private Matrix messaging server in minutes.

One interactive script that sets up a complete, secure Matrix server with **end-to-end encryption**, **voice/video calls**, and **federation** — on any Debian/Ubuntu machine.

## What You Get

| Feature | Details |
|---------|---------|
| 🔒 **E2EE** | End-to-end encryption on all private chats |
| 📞 **Voice/Video** | Calls via TURN/STUN (works across networks) |
| 🌐 **Federation** | Talk to anyone on Matrix (matrix.org, etc.) |
| 🔐 **Auto TLS** | Let's Encrypt certificates via Caddy |
| 🛡️ **Hardened** | Firewall, fail2ban, swap, auto-updates |
| 📱 **IPv4 + IPv6** | Dual-stack ready |

## Components

| Component | Role |
|-----------|------|
| [Conduit](https://conduit.rs/) | Matrix homeserver (Rust, lightweight) |
| [Caddy](https://caddyserver.com/) | Reverse proxy + auto TLS |
| [Coturn](https://github.com/coturn/coturn) | TURN/STUN for voice/video calls |

## Requirements

- **OS:** Debian 13 or Ubuntu 22.04+ (any machine — VPS, home lab, etc.)
- **RAM:** 512MB minimum (1GB+ recommended)
- **Disk:** 10GB+ free
- **Ports:** 80, 443, 8448, 3478, 5349 accessible
- **Domain:** With DNS access (any provider)

## Quick Start

```bash
# SSH into your server (root or any user with sudo)
ssh user@your-server

# Download and run
curl -fsSL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/install.sh -o install.sh
sudo bash install.sh    # or: bash install.sh (if already root)
```

## Interactive Menu

The script provides a menu-driven interface:

```
╔═══════════════════════════════════════════╗
║   🏠 Matrix Conduit Server Manager        ║
╚═══════════════════════════════════════════╝

  1) Prepare      — What you need before installing
  2) Install      — Deploy Matrix server
  3) Health Check — Verify services & security
  4) Registration — Open/close/create accounts
  5) Services     — Start/stop/restart/update/logs
  0) Exit
```

### 1. Prepare

Tells you exactly what DNS records and settings you need **before** installing. Just enter your domain and get a complete checklist.

### 2. Install

Fully automated deployment:
- Docker + Docker Compose
- UFW firewall (only required ports)
- Swap (for low-RAM servers)
- Fail2ban (SSH protection)
- Auto security updates
- Conduit + Caddy + Coturn
- TLS certificates (auto-renewed)
- TURN certificate auto-sync (systemd watcher)

### 3. Health Check

Comprehensive status check:
- All 3 services running
- HTTPS + Federation + IPv6
- Firewall, fail2ban, SSH hardening
- TLS certificate expiry
- Disk and RAM usage
- Registration status

### 4. Registration

- Open/close registration
- Create accounts directly from the script
- Show registration token

### 5. Services

- Start/stop/restart all services
- View live logs
- Update containers
- Resource usage

## Architecture

```
Internet
    │
    ▼
┌─────────┐     ┌─────────┐
│  Caddy   │────▶│ Conduit │  (Docker internal network)
│ :80/443  │     │  :6167  │  ← No port mapping (secure)
│  :8448   │     └─────────┘
└─────────┘
    
┌─────────┐
│ Coturn   │  (host network — required for TURN relay)
│  :3478   │
│  :5349   │
└─────────┘
```

**Security note:** Conduit has **no port mapping** — it's only accessible through Caddy's internal Docker network. This prevents Docker from bypassing firewall rules.

## TURN Configuration

Voice/video calls use UDP-first with TCP fallback:

```
turn:YOUR_MATRIX_HOST?transport=udp   ← Primary (fastest)
turn:YOUR_MATRIX_HOST?transport=tcp   ← Fallback
stun:YOUR_MATRIX_HOST                 ← Peer-to-peer
```

Where `YOUR_MATRIX_HOST` is `matrix.example.com` (delegation mode) or `chat.example.com` (subdomain mode).

> **Why no `turns:` (TLS)?** Element clients prefer TURNS over plain TURN when available, forcing all traffic through TCP even when UDP works fine. This causes unnecessary latency.

## Domain Setup — How It Works

The script supports **two domain modes**. Choose based on how you want your usernames to look:

### Mode 1: Clean Username (Delegation)

Your usernames use the **root domain** while the server runs on a subdomain:

```
Username:   @user:example.com          ← clean!
Server:     https://matrix.example.com  ← where it actually runs
```

This requires `.well-known` delegation — a small JSON file on your root domain that tells Matrix clients where to find the server. The script handles this automatically:

| Your situation | What the script does |
|----------------|---------------------|
| Root domain has **no existing website** | Caddy serves Matrix + `.well-known` — fully automatic ✅ |
| Root domain has **an existing website** | Shows exact config to add to your web server (Nginx, Apache, Traefik) |

**DNS required:** `A` record for `matrix` + `A` record for `@` (if no existing site)

### Mode 2: Subdomain Only (Simple)

Your usernames use the **subdomain** directly — no delegation needed:

```
Username:   @user:chat.example.com     ← slightly longer
Server:     https://chat.example.com    ← same address
```

No `.well-known` needed. Just one DNS record and you're done.

**DNS required:** `A` record for `chat` (or whatever subdomain you pick)

### Which should I choose?

| | Mode 1 (Delegation) | Mode 2 (Subdomain) |
|---|---|---|
| **Username** | `@user:example.com` | `@user:chat.example.com` |
| **Setup** | Slightly more involved | Simplest possible |
| **DNS records** | 2-3 records | 1 record |
| **Root domain** | Must serve `.well-known` | Not involved at all |
| **Best for** | Professional / permanent setup | Quick setup / testing |

> **⚠️ Important:** Your server name (the part after `:` in usernames) is **permanent**. You cannot change it later without creating a new server. Choose carefully!

## Compatible Clients

| Client | Platform | Notes |
|--------|----------|-------|
| [Element](https://element.io/) | iOS / Android / Web / Desktop | Most popular |
| [SchildiChat](https://schildi.chat/) | iOS / Android | Nicer UI |
| [FluffyChat](https://fluffychat.im/) | iOS / Android | Lightweight |

## File Structure

```
/opt/conduit/
├── .env                  # Secrets (domain, tokens)
├── docker-compose.yml    # All 3 services
├── Caddyfile             # Reverse proxy config
├── turnserver.conf       # TURN/STUN config
├── conduit.toml          # Media retention policies
├── certs/                # TLS certs for Coturn
│   ├── turn.crt
│   └── turn.key
└── CREDENTIALS.txt       # Generated credentials (delete after saving!)
```

## License

MIT — Use it, share it, modify it.

## Credits

Built with ❤️ using [Conduit](https://conduit.rs/), [Caddy](https://caddyserver.com/), and [Coturn](https://github.com/coturn/coturn).
