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
# SSH into your server as root
ssh root@your-server

# Download and run
curl -fsSL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/install.sh -o install.sh
bash install.sh
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
turn:matrix.YOUR_DOMAIN?transport=udp   ← Primary (fastest)
turn:matrix.YOUR_DOMAIN?transport=tcp   ← Fallback
stun:matrix.YOUR_DOMAIN                 ← Peer-to-peer
```

> **Why no `turns:` (TLS)?** Element clients prefer TURNS over plain TURN when available, forcing all traffic through TCP even when UDP works fine. This causes unnecessary latency.

## Domain Setup — How It Works

Matrix uses **two different things**:

| Concept | Example | Purpose |
|---------|---------|---------|
| **Server Name** (identity) | `example.com` | Shows in usernames: `@user:example.com` |
| **Server URL** (actual server) | `matrix.example.com` | Where the server actually runs |

The script sets up your Matrix server on `matrix.YOUR_DOMAIN` (subdomain), while your usernames use the clean root domain (`@user:YOUR_DOMAIN`).

### `.well-known` Delegation

For this to work, your **root domain** needs to serve a small JSON file that tells Matrix clients where to find the actual server. The script handles this differently depending on your setup:

| Scenario | What the script does |
|----------|---------------------|
| Root domain has **no existing website** | Caddy serves both Matrix + `.well-known` automatically ✅ |
| Root domain has **an existing website** | Script gives you the exact config to add to your existing web server (Nginx, Apache, Traefik, etc.) |

> **Note:** You do NOT need Cloudflare Workers or any special service for this — any web server can serve the `.well-known` file.

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
