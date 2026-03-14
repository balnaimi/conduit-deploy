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

Open this in your browser: `https://matrix.yourdomain.com/_matrix/client/versions`

You should see a JSON response. If not:
- DNS might not have propagated yet (wait 10-30 minutes)
- Your domain might not point to the right IP
- Ports 80/443 might be blocked by your VPS provider

**Check 3: Did you enter the right homeserver?**

In your app, the homeserver should be:
- Mode 1: `example.com` (just the root domain!)
- Mode 2: `chat.example.com` (your full subdomain)

Common mistake: entering `matrix.example.com` instead of `example.com` in Mode 1.

### "HTTPS certificate error"

Caddy gets certificates automatically from Let's Encrypt. If it fails:

```bash
# Check Caddy logs
cd /opt/conduit && sudo docker compose logs caddy --tail 50
```

Common causes:
- **DNS not ready** — Wait and restart: `sudo docker compose restart caddy`
- **Port 80 blocked** — Let's Encrypt needs port 80 for verification
- **Rate limited** — Too many certificate requests. Wait an hour

### "Voice/video calls don't work"

**Check 1: Are TURN ports open?**
```bash
sudo ufw status | grep -E "3478|5349"
```

**Check 2: Is Coturn running?**
```bash
cd /opt/conduit && sudo docker compose logs coturn --tail 20
```

**Check 3: Is the TLS cert synced?**
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

Visit: `https://federationtester.matrix.org/api/report?server_name=yourdomain.com`

**Check 3: SRV record**
```bash
dig SRV _matrix._tcp.yourdomain.com
```

### "Registration token doesn't work"

**Check 1: Is registration open?**
```bash
sudo bash conduit-deploy.sh
# Choose 4 → Check current status
```

**Check 2: Check the token**
```bash
sudo bash conduit-deploy.sh
# Choose 4 → 4 (Show registration token)
```

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

### "I forgot my registration token"

```bash
sudo grep REGISTRATION_TOKEN /opt/conduit/.env
```

### "I want to start over"

```bash
cd /opt/conduit
sudo docker compose down -v   # -v removes data volumes!
sudo rm -rf /opt/conduit
```

> **⚠️ Warning:** This deletes ALL messages and accounts permanently!

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

## Getting help

1. Check the [FAQ](faq.md)
2. Search existing [GitHub Issues](https://github.com/balnaimi/conduit-deploy/issues)
3. Open a new issue with:
   - What you expected
   - What happened
   - Output of Health Check
   - Your OS version
