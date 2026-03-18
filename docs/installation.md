# 🔧 Installation Guide

## Before you begin

Make sure you've completed:
- [ ] Got a server (VPS) with Debian 13 (other Debian/Ubuntu may work but untested)
- [ ] Got a domain name
- [ ] Set up DNS records (see [Domain Setup](domain-setup.md))
- [ ] Waited a few minutes for DNS to propagate

## What the script installs

The script automatically checks for and installs any missing dependencies:

**Services:**
| Package | Purpose |
|---------|---------|
| Docker | Runs Conduit, Caddy, and Coturn in containers |
| firewalld | Firewall — blocks unauthorized access, handles NAT for Docker |
| Fail2ban | Bans IPs after too many failed login attempts |
| unattended-upgrades | OS security patches (no auto-reboot — you decide when) |

**Utilities (if missing):**
| Command | Package | Used for |
|---------|---------|----------|
| `curl` | curl | Downloads, API calls |
| `openssl` | openssl | Generating tokens/secrets |
| `dig` | dnsutils | DNS verification |
| `ss` | iproute2 | Port availability checks |
| `tar` | tar | Backups |
| `free` | procps | RAM checks |
| `awk` | gawk | Text processing |

> Most are already pre-installed on Debian. The script only installs what's missing.

## Connecting to your server

Open a terminal (or PuTTY on Windows) and connect:

```bash
ssh user@your-server-ip
```

> **First time?** Your VPS provider gives you the IP, username, and password (or SSH key) when you create the server.

## Running the script

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/conduit-deploy.sh -o conduit-deploy.sh

# Run (as root or with sudo)
sudo bash conduit-deploy.sh
```

You'll see the main menu:

```
╔═══════════════════════════════════════════╗
║   🏠 Matrix Conduit Server Manager        ║
╚═══════════════════════════════════════════╝

  1) Prepare      — What you need before installing
  2) Install      — Deploy Matrix server
  3) Health Check — Verify services & security
  4) Services     — Start/stop/restart/update/logs
  5) Uninstall    — Remove everything
  0) Exit
```

## Step 1: Prepare (optional)

Choose **1** to see a personalized checklist. Enter your domain and the script will show you exactly what DNS records to create.

> Already done your DNS setup? Skip to Step 2.

## Step 2: Install

Choose **2** and the script will ask you:

> **Tip:** The script remembers your settings from two sources:
> - **Prepare step** — if you ran Prepare first, your choices are pre-filled
> - **Previous installation** — if you've installed before, the old config is loaded as defaults
>
> Either way, the script tells you where the defaults came from. Press Enter to keep them, or type a new value to override.

### Question 1: Username mode

```
🌐 How do you want your usernames to look?

  1) Clean username — @user:example.com
  2) Subdomain only — @user:chat.example.com
```

### Question 2: Your domain

```
Your domain name: example.com
```

### Question 3: Server subdomain

```
Server subdomain (e.g. matrix, chat, msg) [matrix]:
```

In **both modes**, you choose the subdomain where the server will run. Default is `matrix`, but you can pick any name (e.g. `chat`, `msg`, `im`). This determines the DNS A record you need to create.

### Question 4: Server IP

The script auto-detects this. Just press Enter to confirm. The script validates both the domain format and IP address before proceeding — typos are caught early.

### Question 5: .well-known (Mode 1 only)

```
  A) Root domain has NO existing website — Caddy handles it
  B) Root domain has an existing website — I'll give you instructions
```

### Question 6: Media settings

```
Max upload size in MB [100]:
```

The maximum file size a user can upload (images, videos, documents). Enter a **number in MB only** — do not type "GB" or other units. The maximum allowed value is **1024 MB** (which equals 1 GB). Default is 100 MB, which is fine for most cases.

Examples: `100`, `256`, `512`, `1024`

The script will also ask about:
- **Media storage** — total disk space for all media files (in GB)
- **Cleanup policy** — how long to keep cached and user files (in days)
- **Thumbnail storage** — space for auto-generated previews (in GB)

All fields accept **numbers only**. If you enter letters or invalid input, the script will ask again.

### Then it runs!

The script automatically handles everything in this order:

#### 1. 📦 Installing Docker
Installs Docker Engine and Docker Compose — the container runtime that runs all services. If Docker is already installed, this step is skipped.

#### 2. 🔒 Configuring Firewall (firewalld)
The script installs firewalld (removing UFW/iptables-persistent if present to avoid conflicts), binds the primary network interface to the public zone, enables masquerade for Docker NAT, and opens **only** the ports needed:
| Port | Purpose |
|------|---------|
| 80 | HTTP (redirects to HTTPS, used by Let's Encrypt) |
| 443 | HTTPS (main traffic — web clients connect here) |
| 8448 | Matrix federation (server-to-server communication) |
| 3478 | TURN (voice/video call relay) |
| 5349 | TURN over TLS |

All other ports are blocked. SSH (port 22) remains open.

#### 3. 🛡️ Server Hardening
- **Swap memory** — Adds 2GB swap so the server doesn't crash under load (especially important on 1GB VPS)
- **Fail2ban** — Monitors SSH login attempts and automatically blocks IPs after too many failures
- **Unattended upgrades** — Security patches are installed automatically (no auto-reboot — you decide when)
- **Unnecessary services disabled** — e.g. exim4 mail server (not needed)

#### 4. 📝 Creating Configuration Files
Generates all config files in `/opt/conduit/` based on your choices:
- `.env` — environment variables (domain, IPs, secrets)
- `docker-compose.yml` — defines the 3 containers (Conduit, Caddy, Coturn)
- `Caddyfile` — web server config with automatic HTTPS
- `turnserver.conf` — TURN/STUN server for calls
- `conduit.toml` — Conduit settings (upload limits, media cleanup, etc.)

#### 5. 🚀 Starting Services
- Pulls Docker images for Conduit, Caddy, and Coturn
- Starts all 3 containers
- Waits for Let's Encrypt to issue TLS certificates (up to 60 seconds)
- Syncs TLS certificates to Coturn for secure voice/video calls
- Sets up automatic certificate renewal
- Configures UDP 443 → 5349 redirect for TURN (voice/video calls on restricted networks)
- The UDP redirect is managed by firewalld (`--add-forward-port`) and persists across reboots automatically

> **⚠️ If this step fails**, the most common cause is DNS not pointing to your server. See [Troubleshooting](troubleshooting.md).

#### 6. ✅ Installation Complete — Summary
The script shows a full summary of everything that was installed:
- All services and their status
- Security hardening applied
- Your server URL, IP addresses
- Where credentials are saved

#### 7. 👤 Create Your Admin Account
The script asks you to create the **first account** — this automatically becomes the server admin. You'll use this account to:
- Sign in to Element (or any Matrix client)
- Access the **Admin Room** for server management
- Create other users, reset passwords, etc.

After the account is created, you'll see:
- Your full Matrix ID (e.g. `@username:example.com`)
- Login instructions for Element
- Quick reference for Admin Room commands

```
═══ Installation Complete! 🎉 ═══

  Your Matrix server is running at:
  https://matrix.example.com

═══ Create Your Admin Account ═══

  ⚠  This is the ONLY admin account.

Username: yourname
Password: ********

✅ Account created: @yourname:example.com

═══ You're All Set! 🎉 ═══
```

**⚠️ Security:** Your credentials are saved in plain text at `/opt/conduit/CREDENTIALS.txt`. The script will ask if you want to delete this file — **say yes** after you've saved the info above. If you forget your password later, use **Services → Password Recovery** (option `p`) — no credentials file needed, it uses Conduit's emergency password feature to securely reset any account.

## Step 3: Verify

Choose **3** (Health Check) to make sure everything is working:

```
  Services:
  ✅ conduit is running
  ✅ caddy is running
  ✅ coturn is running

  Connectivity:
  ✅ HTTPS working
  ✅ Federation port 8448 working

  Security:
  ✅ firewalld active
  ✅ firewalld interface bound (eth0)
  ✅ firewalld masquerade enabled
  ✅ Docker internet access OK
  ✅ Fail2ban active
  ✅ Auto security patches enabled
  ✅ No reboot pending

  ✅ All checks passed! Server is healthy.
```

## Step 4: Your admin account

During installation, the script automatically creates your first admin account. This is the **only account with admin privileges**. It has access to the **Admin Room** where you can:

- Create additional user accounts
- Reset passwords
- Manage registration settings
- Monitor server statistics

To create more accounts, log in to Element and find the **"Conduit Admin Room"**, then type:

```
@conduit:example.com create-user alice SecurePassword123
```

> **See the full guide:** [Admin Room documentation](admin-room.md) for all available commands.

If you forget your admin password, use **Services → Password Recovery** (option `p`) from the script menu. No credentials file needed — it uses Conduit's emergency password feature to securely reset any account.

## What's next?

- [After Installation](after-install.md) — Set up your phone, invite people
- [FAQ](faq.md) — Common questions answered
- [Troubleshooting](troubleshooting.md) — Something not working?

---

**Need help?** Open an issue on [GitHub](https://github.com/balnaimi/conduit-deploy/issues)
