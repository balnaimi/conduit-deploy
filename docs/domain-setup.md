# 🌐 Domain Setup

## Why do I need a domain?

Your domain is your **address** on the Matrix network. When someone wants to message you, they'll use:

```
@yourname:example.com
```

Think of it like an email address — the part after `:` is your domain.

## Two ways to set it up

The script gives you two options. Here's the difference in plain English:

### Option 1: Clean Username (Delegation)

```
Your address:  @alice:example.com
Server lives:  matrix.example.com  (or chat.example.com — you choose the subdomain!)
```

**The good:** Your username is short and clean
**The catch:** You need to set up a small "pointer" on your root domain

> **Note:** The script will ask you to choose a subdomain (default: `matrix`). You can pick any name: `matrix`, `chat`, `msg`, `im`, etc.

**How it works:**
```
Someone tries to reach @alice:example.com
        ↓
Goes to example.com and asks "where's the Matrix server?"
        ↓
example.com replies "it's at matrix.example.com" (or whatever subdomain you chose)
        ↓
Connects to the server ✅
```

### Option 2: Subdomain Only (Simple)

```
Your address:  @alice:chat.example.com
Server lives:  chat.example.com
```

**The good:** Easiest to set up — just one DNS record
**The catch:** Your username is a bit longer

> ⚠️ **Note:** Your username will be `@user:chat.example.com` instead of `@user:example.com` — longer but simpler setup. Choose based on whether you prefer shorter usernames (Option 1) or easier DNS configuration (Option 2).

**How it works:**
```
Someone tries to reach @alice:chat.example.com
        ↓
Goes directly to chat.example.com ✅
```

### Quick comparison

| | Clean Username | Subdomain Only |
|---|---|---|
| Your address | `@you:example.com` | `@you:chat.example.com` |
| Setup time | 10 minutes | 5 minutes |
| DNS records | 2 (A + A) | 1 (A only) |
| Difficulty | Easy | Easiest |
| Looks professional? | ✅ Yes | ⚠️ Okay |

> **⚠️ Important:** You **cannot change this later!** Your server name is permanent. If you pick `chat.example.com` now, you can't switch to `example.com` later without starting over.

---

## Setting up DNS (both options)

### What is DNS?

DNS is like a phone book for the internet. It translates names (like `example.com`) into IP addresses (like `123.45.67.89`). You need to add entries so people can find your server.

### Where to change DNS?

Go to wherever you bought your domain:
- **Cloudflare** → DNS → Records
- **Namecheap** → Domain List → Manage → Advanced DNS
- **Porkbun** → Domain Management → DNS Records

---

## Option 1 Setup: Clean Username

You need **2-3 DNS records** (no SRV record needed!):

### Record 1: Point your root domain to the server

| Field | Value |
|-------|-------|
| **Type** | A |
| **Name** | `@` (root) |
| **Value** | Your server's IP (e.g. `123.45.67.89`) |
| **Proxy** | OFF / DNS Only |

> This makes `example.com` serve the `.well-known` delegation files

### Record 2: Point your chosen subdomain to your server

| Field | Value |
|-------|-------|
| **Type** | A |
| **Name** | Your chosen subdomain (e.g. `matrix`, `chat`, `msg`) |
| **Value** | Your server's IP (e.g. `123.45.67.89`) |
| **Proxy** | OFF / DNS Only |

> This creates `{subdomain}.example.com` → your server (where Conduit runs). The script will ask you to choose a subdomain during setup — default is `matrix`.

### Record 3: IPv6 (optional but recommended)

Add AAAA records for both `@` and your chosen subdomain if your server has IPv6.

> **Why IPv6?** IPv6 allows clients on modern networks to connect faster. If your VPS provider offers IPv6, enable it — it's future-proof and improves connectivity for users on IPv6-only networks.

### ⚠️ Why DNS records MUST be correct before installing

The script uses **Caddy** as a web server, which automatically gets TLS (HTTPS) certificates from **Let's Encrypt**. For this to work:

1. **Your subdomain** (e.g. `matrix.example.com`) **must resolve to your server's IP** — Let's Encrypt will try to connect to your server via this domain to verify you own it
2. **Your root domain** (e.g. `example.com`) **must also resolve to your server's IP** (in Mode 1) — Caddy needs to get a certificate for both domains
3. **Cloudflare proxy must be OFF** (DNS Only / grey cloud) — Let's Encrypt needs to reach your server directly, not Cloudflare's proxy

If DNS is not set up correctly:
- Let's Encrypt **cannot issue certificates** → your server won't have HTTPS → clients can't connect
- The script will detect this and ask you to **fix DNS first** or **retry** after you've fixed it

**Tip:** After adding DNS records, verify propagation at [dnschecker.org](https://dnschecker.org) before running the installer. It usually takes 5-30 minutes.

### The "pointer" (.well-known)

Since your username uses `example.com` but the server is at `matrix.example.com`, you need a small pointer. **The script handles this for you!** During installation, it will ask:

- **"Does your root domain have an existing website?"**
  - **No** → The script sets everything up automatically via Caddy. Just point the `@` A record to your server IP (Record 1 above).
  - **Yes** → The script shows you exactly what `.well-known` JSON files to add to your existing web server. See the note below.

> **⚠️ Existing website scenario:** If `example.com` already hosts a website on a **different server**, you'll choose Option B during install. The script will give you the exact JSON to serve at `example.com/.well-known/matrix/server` and `example.com/.well-known/matrix/client` on your existing web server. **Note:** This scenario has not been fully tested yet — it should work but please report any issues.

### What about SRV records?

You might see other guides mention an `SRV` record (`_matrix._tcp`). **You don't need one!** Here's why:

- **SRV records are an old method.** The script uses `.well-known` (the modern, recommended way per the Matrix spec).
- `.well-known` takes priority over SRV records — if `.well-known` is working, SRV is ignored by clients.
- SRV records are only needed if you **absolutely cannot serve files on your root domain** — which is very rare. Most people can serve `.well-known` files easily via Caddy, Nginx, or any web server.

**In simple terms:** `.well-known` is like putting up a sign at your front door. SRV is like putting up a sign down the street. If the front door sign exists, nobody looks at the street sign.

**TL;DR:** The script uses `.well-known` → no SRV needed. ✅

---

## Option 2 Setup: Subdomain Only

You only need **1-2 DNS records**:

### Record 1: Point your subdomain to your server

| Field | Value |
|-------|-------|
| **Type** | A |
| **Name** | `chat` (or whatever you want) |
| **Value** | Your server's IP (e.g. `123.45.67.89`) |
| **Proxy** | OFF / DNS Only |

> This creates `chat.example.com` → your server

### Record 2: IPv6 (optional)

Same as above, but with your subdomain name.

That's it! No pointer needed. 🎉

---

## How to verify it's working

After adding DNS records, **wait 5-30 minutes** for DNS propagation, then check:

```bash
# On Linux/Mac:
ping matrix.example.com

# Or use an online tool to verify globally:
# https://dnschecker.org
```

If it shows your server's IP in multiple locations, you're good to go!

> **Note:** DNS propagation time varies by provider. Some are fast (5 minutes), others take longer (up to an hour). Use dnschecker.org to see if your DNS has propagated worldwide.

---

**Next:** [Installation Guide](installation.md) — Run the script and get chatting!
