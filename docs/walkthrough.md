# Walkthrough: Subdomain Mode

A complete real-world example — from a blank server to sending your first message.

This guide uses **subdomain mode** (Mode 2), which gives you usernames like `@user:matrix.example.com`.

---

## What We'll Do

1. [Prerequisites](#1-prerequisites) — What you need before starting
2. [DNS Setup](#2-dns-setup) — Point your domain to your server
3. [Run the Installer](#3-run-the-installer) — Launch the script and configure
4. [Health Check](#4-health-check) — Verify everything works
5. [Create Accounts](#5-create-accounts) — Add users to your server
6. [Sign In & Chat](#6-sign-in--chat) — Connect with a Matrix client

---

## 1. Prerequisites

Before you start, make sure you have:

| What | Details |
|------|---------|
| **A VPS / server** | Debian 13 or Ubuntu 22.04+ with at least 512MB RAM and 10GB disk |
| **Root access** | Either logged in as `root`, or a user with `sudo` |
| **A domain name** | Any domain you own (e.g., `example.com`) |
| **DNS access** | Ability to add A and AAAA records |

> **💡 Tip:** Not sure which mode to choose? Check the [Domain Setup](domain.md) page first.

---

## 2. DNS Setup

Go to your DNS provider and add these records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| `A` | `matrix` | Your server's IPv4 (e.g. `188.166.248.91`) | 3600 |
| `AAAA` | `matrix` | Your server's IPv6 (if available) | 3600 |

Wait a few minutes for DNS to propagate, then verify:

```bash
dig matrix.example.com +short
# Should return your server's IP
```

---

## 3. Run the Installer

SSH into your server and run the script:

```bash
# SSH into your server
ssh root@your-server-ip

# Download and run the installer
curl -sL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/conduit-deploy.sh | bash
```

### 3a. Choose Your Mode

```
* How do you want your usernames to look?

  1) Clean username — @user:example.com (server at matrix.example.com)
  2) Subdomain only — @user:matrix.example.com (simpler, no delegation)

Choose [1/2]: 2
```

### 3b. Enter Your Domain

```
Your domain name: example.com
Subdomain for the server [matrix]: matrix
VPS public IP [188.166.248.91]: ↵ (press Enter to accept)
```

> **💡 Note:** Enter just the root domain (e.g. `example.com`), not the full address.

### 3c. Media Settings

The defaults work well for most setups — just press Enter for each:

| Setting | Default | What It Means |
|---------|---------|---------------|
| Max upload size | 100 MB | Largest file a user can send |
| Max media storage | 10 GB | Total space for all files |
| Cached files idle expiry | 30 days | Delete federated cache after 30 days idle |
| Cached files max age | 90 days | Hard limit for federated cache |
| User files idle expiry | 365 days | Your users' files after 1 year idle |
| Thumbnail storage | 1 GB | Auto-generated image previews |

### 3d. Confirm & Install

```
Summary:
  Server name: matrix.example.com
  Usernames:   @user:matrix.example.com
  Matrix URL:  https://matrix.example.com
  VPS IP:      188.166.248.91

Start installation? [Y/n]: Y
```

The installer will:
1. Install missing dependencies (Docker, UFW, Fail2ban)
2. Verify ports and DNS
3. Optionally set your timezone
4. Generate configs and secrets
5. Pull Docker images and start services
6. Obtain a Let's Encrypt TLS certificate
7. Set up TURN server for voice/video calls

> **⏱️ How long?** About 5–10 minutes on first install.

---

## 4. Health Check

From the main menu, choose **`3`** (Health Check). Everything should be green:

```
Services:
  ✅ conduit is running
  ✅ caddy is running
  ✅ coturn is running

Connectivity:
  ✅ HTTPS working (matrix.example.com)
  ✅ Federation port 8448 working
  ✅ IPv6 working

Security:
  ✅ UFW firewall active
  ✅ Fail2ban active
  ✅ SSH password auth disabled

TLS Certificates:
  ✅ Coturn TLS cert valid (89 days left)
  ✅ TLS auto-sync watcher active

Resources:
  ✅ Disk: 4.1G used / 20G free
  ✅ RAM: 442Mi / 967Mi

Registration:
  ✅ Registration is CLOSED
```

If any check fails, see [Troubleshooting](troubleshooting.md).

---

## 5. Create Accounts

Your server is running but has no users yet.

### Option A: Using the Script (Recommended)

From the main menu: **`4`** (Registration) → **`3`** (Create account via API)

```
Username (without @, lowercase letters/numbers/dots/hyphens): alice
Password (min 8 characters): MySecurePass123!
```

The script handles everything automatically:
1. Temporarily opens registration (with token protection)
2. Creates the account via the Matrix API
3. Closes registration again immediately

```
ℹ Temporarily opening registration...
  Registration briefly open (token still required). Will close after account creation.
ℹ Creating account @alice:matrix.example.com...
✅ Account created: @alice:matrix.example.com
ℹ Registration closed again
```

> **🔒 Security:** Registration stays closed between account creations. Even while briefly open, a token is required — random signups cannot get in.

Create as many accounts as you need — choose `3` again from the Registration menu for each one.

### Option B: Open Registration (Self-Service)

If you want users to sign up themselves:

1. From the Registration menu, choose **`1`** (Open registration)
2. Share your server address and registration token with users
3. When done, choose **`2`** (Close registration)

To see your registration token: choose **`4`** (Show registration token).

> **⚠️ Don't forget!** Always close registration when done. The script will warn you on startup if registration is left open.

---

## 6. Sign In & Chat

### 6a. Download a Client

| Client | Platforms | Link |
|--------|-----------|------|
| **Element** | Web, Desktop, iOS, Android | [element.io](https://element.io/download) |
| **SchildiChat** | Desktop, iOS, Android | [schildi.chat](https://schildi.chat/) |
| **FluffyChat** | iOS, Android, Linux | [fluffychat.im](https://fluffychat.im/) |

### 6b. Sign In

1. Open the app and tap **"Sign In"**
2. Change the homeserver to: `matrix.example.com`
3. Enter your **username** (e.g. `alice`) and **password**
4. You're in! 🎉

### 6c. Send a Message

1. Click **"+"** → **"New direct message"**
2. Type the other user's Matrix ID: `@bob:matrix.example.com`
3. Send a message — it's end-to-end encrypted by default! 🔐

> **🌐 Federation:** Your server can talk to any other Matrix server. Try messaging someone on `matrix.org` — it just works!

---

## 🎉 You're Done!

Your Matrix server is running, secured, and ready to use. Next steps:

- **Set up verification keys** — Enable cross-signing in your client
- **Create a backup** — Services menu (`5` → `7`)
- **Set up SSH keys** — See [After Install](after-install.md)
- **Explore the architecture** — See [Architecture](architecture.md)
