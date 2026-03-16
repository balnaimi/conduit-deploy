# 🚀 Getting Started

## What is this?

This project lets you set up your **own private messaging server** — like WhatsApp or Telegram, but:

- **You own it** — your messages stay on your server, not someone else's
- **It's encrypted** — nobody can read your messages, not even you as the server admin
- **It's free** — no subscriptions, no limits, no ads
- **It talks to others** — you can message anyone on the Matrix network (millions of users)

## What do I need?

| Thing | Why | Cost |
|-------|-----|------|
| A **server** (VPS) | Where your messaging server lives | ~$5/month |
| A **domain name** | Your address (like `example.com`) | ~$10/year |
| **30 minutes** | That's how long setup takes | Free 😊 |

### Where to get a server?

This project was tested on [DigitalOcean](https://www.digitalocean.com/) ($6/mo Droplet — 1 GB RAM, 1 CPU, 25 GB SSD, Debian 13). Other providers may work but are untested:

| Provider | Cheapest Plan | Notes |
|----------|--------------|-------|
| [DigitalOcean](https://digitalocean.com) | $6/month | **Tested** ✅ |
| [Hetzner](https://hetzner.com) | ~€4/month | Untested — may work |
| [Vultr](https://vultr.com) | $6/month | Untested — may work |
| [Oracle Cloud](https://cloud.oracle.com) | **Free tier!** | Untested — ARM, may need adjustments |

> I have no affiliation with DigitalOcean — just a long-time user who likes their service.

### Where to get a domain?

| Provider | Price | Notes |
|----------|-------|-------|
| [Cloudflare](https://cloudflare.com) | At cost (~$10/yr) | No markup, great DNS |
| [Namecheap](https://namecheap.com) | ~$10/yr | Popular, easy |
| [Porkbun](https://porkbun.com) | ~$10/yr | Cheap, good UI |

## The Big Picture

Here's what happens when you run the script:

```
┌─────────────────────────────────────────────┐
│              Your Server (VPS)               │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Caddy    │  │ Conduit  │  │  Coturn   │  │
│  │ (gateway) │→ │ (chat)   │  │ (calls)   │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│                                              │
│  🔒 Firewall  🛡️ Fail2ban  📜 OS Patches     │
└─────────────────────────────────────────────┘
         ↑
    Your phone/laptop connects here
    (Element, SchildiChat, etc.)
```

**Three services work together:**

1. **Caddy** — The front door. Handles encryption (HTTPS) and directs traffic
2. **Conduit** — The brain. Stores messages, manages accounts, handles encryption
3. **Coturn** — The phone. Makes voice and video calls work across networks

## Step by Step

### Step 1: Get your server ready

1. Buy a VPS from any provider above
2. Choose **Debian 13** as the operating system
3. Note down the **IP address** they give you

### Step 2: Get your domain ready

1. Buy a domain (or use one you already have)
2. Go to DNS settings → See [Domain Setup](domain-setup.md) for details
3. Point your domain to your server's IP address

### Step 3: Run the script

```bash
# Connect to your server
ssh user@your-server-ip

# Download the script
curl -fsSL https://raw.githubusercontent.com/balnaimi/conduit-deploy/main/conduit-deploy.sh -o conduit-deploy.sh

# Run it
sudo bash conduit-deploy.sh
```

The script will guide you through everything with a friendly menu!

### Step 4: Create your account

After installation, the script lets you create accounts right away. Or use the **Registration** menu later.

### Step 5: Download an app and sign in

Download one of these apps on your phone:

| App | iOS | Android | Best for |
|-----|-----|---------|----------|
| **Element** | [App Store](https://apps.apple.com/app/element-messenger/id1083446067) | [Google Play](https://play.google.com/store/apps/details?id=im.vector.app) | Most features |
| **SchildiChat** | [App Store](https://apps.apple.com/app/schildichat/id1634348070) | [Google Play](https://play.google.com/store/apps/details?id=de.spiritcroc.riotx) | Nicer interface |
| **FluffyChat** | [App Store](https://apps.apple.com/app/fluffychat/id1551469600) | [Google Play](https://play.google.com/store/apps/details?id=chat.fluffy.fluffychat) | Simple & light |

When signing in:
1. Tap **"Sign in"**
2. Change the homeserver to **your domain** (e.g. `example.com`)
3. Enter your username and password
4. Done! Start chatting 🎉

---

**Next:** [Domain Setup](domain-setup.md) — How to set up your domain (with pictures!)
