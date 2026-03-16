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
| UFW | Firewall — blocks unauthorized access |
| Fail2ban | Bans IPs after too many failed login attempts |
| unattended-upgrades | OS security patches (no auto-reboot — you decide when) |
| iptables-persistent | Saves firewall rules across reboots |

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

> **Tip:** If you ran **Prepare** first, your domain and mode choices will be pre-filled as defaults — just press Enter to keep them.

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

### Question 3: Subdomain (Mode 2 only)

```
Subdomain for the server (e.g. chat, matrix, msg): chat
```

### Question 4: Server IP

The script auto-detects this. Just press Enter to confirm. The script validates both the domain format and IP address before proceeding — typos are caught early.

### Question 5: .well-known (Mode 1 only)

```
  A) Root domain has NO existing website — Caddy handles it
  B) Root domain has an existing website — I'll give you instructions
```

### Question 6: Upload size

```
Max upload size in MB [100]:
```

How large files can people send? 100MB is fine for most cases.

### Then it runs!

The script automatically:

1. ✅ Installs Docker
2. ✅ Sets up the firewall (only opens needed ports)
3. ✅ Adds swap memory (for small servers)
4. ✅ Installs fail2ban (blocks hackers)
5. ✅ Enables OS security patches (no auto-reboot)
6. ✅ Creates all configuration files
7. ✅ Starts the services
8. ✅ Gets TLS certificates (HTTPS)
9. ✅ Sets up certificate auto-renewal

At the end, you'll see:

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
  ✅ UFW firewall active
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
@conduit:yourdomain.com create-user alice SecurePassword123
```

> **See the full guide:** [Admin Room documentation](admin-room.md) for all available commands.

If you forget your admin password, use **Services → Password Recovery** (option `p`) from the script menu. No credentials file needed — it uses Conduit's emergency password feature to securely reset any account.

## What's next?

- [After Installation](after-install.md) — Set up your phone, invite people
- [FAQ](faq.md) — Common questions answered
- [Troubleshooting](troubleshooting.md) — Something not working?

---

**Need help?** Open an issue on [GitHub](https://github.com/balnaimi/conduit-deploy/issues)
