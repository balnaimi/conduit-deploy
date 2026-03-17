# 🔧 Troubleshooting

## Quick diagnosis

First, run the Health Check:

```bash
sudo bash conduit-deploy.sh
# Choose 3 (Health Check)
```

This checks everything automatically and tells you what's wrong.

---

## Common Issues

### "I can't connect from my phone"

**Check 1: Is the server running?**
```bash
cd /opt/conduit && sudo docker compose ps
```
All 3 services (conduit, caddy, coturn) should show "running".

**Check 2: Is HTTPS working?**

Open this in your browser: `https://matrix.example.com/_matrix/client/versions`

You should see a JSON response. If not:
- DNS might not have propagated yet (wait 10-30 minutes)
- Your domain might not point to the right IP
- Ports 80/443 might be blocked by your VPS provider

**Check 3: Did you enter the right homeserver?**

In your app, the homeserver should be:
- Mode 1: `example.com` (just the root domain!)
- Mode 2: `chat.example.com` (your full subdomain)

Common mistakes:
- Mode 1: entering `matrix.example.com` instead of `example.com`
- Mode 2: entering `matrix.example.com` as the domain AND `matrix` as the subdomain → results in `matrix.matrix.example.com`!

**Tip:** The domain field always means the **root domain** (e.g. `example.com`). The script adds the subdomain for you.

### "HTTPS certificate error"

Caddy gets TLS certificates automatically from **Let's Encrypt**. This requires:
- **A records** pointing your subdomain (and root domain in Mode 1) to your server's IP
- **Port 80 open** — Let's Encrypt uses HTTP-01 challenge to verify domain ownership
- **Cloudflare proxy OFF** — DNS Only (grey cloud), not proxied (orange cloud)

```bash
# Check Caddy logs
cd /opt/conduit && sudo docker compose logs caddy --tail 50
```

Common causes:
- **DNS not pointing to your server** — The most common issue. Verify with `dig your-subdomain.example.com A +short` — it should return your VPS IP. If not, fix the A record and wait 5-30 minutes
- **Port 80 blocked** — Let's Encrypt needs port 80 for verification. Check with `sudo ufw status | grep 80`
- **Cloudflare proxy enabled** — Turn off the orange cloud (proxy) in Cloudflare DNS settings. Use grey cloud (DNS Only)
- **Rate limited** — Too many certificate requests. Wait an hour
- **Wrong domain entered during install** — If you entered the subdomain instead of the root domain, reinstall with the correct value

### "Voice/video calls don't work"

**Check 1: Is the UDP 443 → 5349 redirect active?**
```bash
sudo iptables -t nat -L PREROUTING -n | grep 5349
```
If nothing shows up, the redirect is missing. Fix:
```bash
sudo systemctl restart conduit-iptables.service
# Or if the service doesn't exist:
sudo iptables -t nat -A PREROUTING -p udp --dport 443 -j REDIRECT --to-port 5349
```

> **Why this matters:** Some networks block port 5349 but allow 443. This redirect lets TURN traffic come in on UDP 443 and reach Coturn on 5349. The script creates a systemd service (`conduit-iptables.service`) that applies this rule automatically on every boot — no conflict with UFW.

**Check 2: Are TURN ports open?**
```bash
sudo ufw status | grep -E "3478|5349"
```

**Check 3: Is Coturn running?**
```bash
cd /opt/conduit && sudo docker compose logs coturn --tail 20
```

**Check 4: Is the TLS cert synced?**
```bash
ls -la /opt/conduit/certs/
```

If `turn.crt` and `turn.key` are missing or old:
```bash
# Restart to trigger cert sync
cd /opt/conduit && sudo docker compose restart
```

### "Federation doesn't work (can't message people on other servers)"

**Check 1: Is port 8448 open?**
```bash
sudo ufw status | grep 8448
```

**Check 2: Test federation**

Visit: `https://federationtester.matrix.org/api/report?server_name=example.com`

**Check 3: .well-known delegation (Clean Username mode only)**
```bash
curl -s https://example.com/.well-known/matrix/server
# Should return: {"m.server": "matrix.example.com:443"}
```

> **Note:** If you're using `.well-known` delegation (the default), you do NOT need an SRV record. The `.well-known` method takes priority. SRV is only a fallback for rare cases where you cannot serve `.well-known` files.

### "Registration token doesn't work"

Registration is **closed by default** for security. The token is only used if you enable self-registration via the Admin Room:

```
@conduit:example.com allow-registration true
```

For normal account creation, use the Admin Room instead:

```
@conduit:example.com create-user alice SecurePassword123
```

See the [Admin Room guide](admin-room.md) for more details.

### "I forgot my admin password"

Use **Services → Password Recovery** (option `p`) from the script menu:

```bash
sudo bash conduit-deploy.sh
# Choose: 4 (Services) → p (Password Recovery)
```

The script uses Conduit's emergency password feature to securely reset any account — no credentials file needed.

### "Server is slow / high memory"

**Check resources:**
```bash
sudo bash conduit-deploy.sh
# Choose 5 → 6 (Resource usage)
```

**Add swap if needed:**
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### "Health Check says reboot required"

This means a kernel or critical security update was installed. Your server is still running fine on the old kernel — nothing is broken.

Reboot when it's convenient for you (during low activity):

```bash
sudo reboot
```

Your Matrix services will restart automatically after the reboot. The server **never reboots on its own** — you decide when.

### "I forgot my registration token"

Your token is always stored in the `.env` file:

```bash
sudo grep REGISTRATION_TOKEN /opt/conduit/.env
```

Or check `/opt/conduit/CREDENTIALS.txt` if you haven't deleted it yet.

### "I want to start over"

```bash
cd /opt/conduit
sudo docker compose down -v   # -v removes data volumes!
sudo rm -rf /opt/conduit
```

> **⚠️ Warning:** This deletes ALL messages and accounts permanently! The script auto-creates a backup when you choose Reinstall, but `rm -rf` does not.

---

## Viewing logs

```bash
# All services
cd /opt/conduit && sudo docker compose logs -f

# Just one service
sudo docker compose logs -f conduit
sudo docker compose logs -f caddy
sudo docker compose logs -f coturn
```

## SSH session drops during script operations

If your SSH connection drops while running the script, this is usually caused by **idle timeouts** on your SSH server.

**Quick fix** — add this to your local `~/.ssh/config`:
```
Host *
    ServerAliveInterval 15
    ServerAliveCountMax 10
```

Or connect with:
```bash
ssh -o ServerAliveInterval=15 user@your-server
```

> **Note:** The script isolates all Docker operations from the terminal to prevent disconnects. If the script itself causes SSH to drop (not just idle timeout), please [report it](https://github.com/balnaimi/conduit-deploy/issues).

---

## Getting help

1. Check the [FAQ](faq.md)
2. Search existing [GitHub Issues](https://github.com/balnaimi/conduit-deploy/issues)
3. Open a new issue with:
   - What you expected
   - What happened
   - Output of Health Check
   - Your OS version
