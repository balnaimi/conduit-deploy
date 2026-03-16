# 🌐 Domain Setup

## Why do I need a domain?

Your domain is your **address** on the Matrix network. When someone wants to message you, they'll use:

```
@yourname:yourdomain.com
```

Think of it like an email address — the part after `:` is your domain.

## Two ways to set it up

The script gives you two options. Here's the difference in plain English:

### Option 1: Clean Username (Delegation)

```
Your address:  @alice:example.com
Server lives:  matrix.example.com
```

**The good:** Your username is short and clean
**The catch:** You need to set up a small "pointer" on your root domain

**How it works:**
```
Someone tries to reach @alice:example.com
        ↓
Goes to example.com and asks "where's the Matrix server?"
        ↓
example.com replies "it's at matrix.example.com"
        ↓
Connects to matrix.example.com ✅
```

### Option 2: Subdomain Only (Simple)

```
Your address:  @alice:chat.example.com
Server lives:  chat.example.com
```

**The good:** Easiest to set up — just one DNS record
**The catch:** Your username is a bit longer

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

### Record 2: Point `matrix` to your server

| Field | Value |
|-------|-------|
| **Type** | A |
| **Name** | `matrix` |
| **Value** | Your server's IP (e.g. `123.45.67.89`) |
| **Proxy** | OFF / DNS Only |

> This creates `matrix.example.com` → your server (where Conduit runs)

### Record 3: IPv6 (optional but recommended)

Add AAAA records for both `@` and `matrix` if your server has IPv6.

### The "pointer" (.well-known)

Since your username uses `example.com` but the server is at `matrix.example.com`, you need a small pointer. **The script handles this for you!** During installation, it will ask:

- **"Does your root domain have an existing website?"**
  - **No** → The script sets everything up automatically via Caddy. Just point the `@` A record to your server IP (Record 1 above).
  - **Yes** → The script shows you exactly what `.well-known` JSON files to add to your existing web server. See the note below.

> **⚠️ Existing website scenario:** If `example.com` already hosts a website on a **different server**, you'll choose Option B during install. The script will give you the exact JSON to serve at `example.com/.well-known/matrix/server` and `example.com/.well-known/matrix/client` on your existing web server. **Note:** This scenario has not been fully tested yet — it should work but please report any issues.

### What about SRV records?

You might see other guides mention an `SRV` record (`_matrix._tcp`). **You don't need one!** Here's why:

- The `.well-known` delegation that the script sets up is the **recommended** method per the Matrix spec
- `.well-known` takes priority over SRV records — if `.well-known` is working, SRV is ignored
- SRV records are only useful as a **fallback** if you absolutely cannot serve `.well-known` files on your root domain (e.g., your domain has no web server at all and you can't add one)

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

After adding DNS records, wait a few minutes, then check:

```bash
# On Linux/Mac:
ping matrix.example.com

# Or use an online tool:
# https://dnschecker.org
```

If it shows your server's IP, you're good to go!

---

**Next:** [Installation Guide](installation.md) — Run the script and get chatting!
