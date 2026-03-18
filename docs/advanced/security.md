# 🛡️ Security Details

## What the script secures

The installation script applies several security measures automatically:

### Firewall (firewalld)

The script uses firewalld (not UFW) because it handles both regular port rules and NAT/masquerade in one place — which Docker needs for internet access from containers.

During install, the script:
- Removes UFW/iptables-persistent if present (to avoid conflicts)
- Installs and enables firewalld
- **Binds the primary network interface** to the public zone (without this, rules have no effect)
- Enables **masquerade** (required for Docker container NAT)

Only these ports are open:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH (remote access) |
| 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | TCP | HTTPS (main traffic) |
| 8448 | TCP | Matrix federation |
| 3478 | TCP+UDP | TURN/STUN |
| 5349 | TCP+UDP | TURN over TLS |
| 49152-65535 | UDP | Media relay range |

Everything else is **blocked by default**.

### Docker network isolation

Conduit (the chat server) has **no port mapping** — it's only accessible through Caddy's internal Docker network:

```
Internet → Caddy (ports 80/443/8448) → [internal network] → Conduit
                                                              ↑
                                              Not reachable from internet!
```

This prevents Docker from bypassing the firewall (a common security issue).

### Fail2ban

Automatically blocks IPs that fail SSH login too many times. Protects against brute-force attacks.

### OS security patches

`unattended-upgrades` is installed and configured to automatically download and install OS security patches. 

**Important:** The system will **never reboot automatically**. If a kernel update requires a reboot, the Health Check will tell you:

```
[!] System reboot required (kernel or critical update pending)
    Run 'sudo reboot' when you're ready — your services will restart automatically.
```

You decide when to reboot — the server won't restart in the middle of a conversation.

### TLS everywhere

- HTTPS for all web traffic (Caddy + Let's Encrypt)
- TLS for TURN connections
- Certificates renew automatically

## End-to-end encryption (E2EE)

Matrix supports E2EE using the **Olm/Megolm** protocol (similar to Signal's protocol):

- Messages are encrypted **on the sender's device**
- Only the intended recipients can decrypt them
- The server **cannot read** encrypted messages
- Each device has its own encryption keys

### What the server CAN see (even with E2EE):
- Who is talking to whom (metadata)
- When messages are sent
- Room membership
- Unencrypted room names/topics

### What the server CANNOT see:
- Message content (in encrypted rooms)
- Files (in encrypted rooms)
- Voice/video call content

## Recommendations

### SSH hardening

The script doesn't modify SSH settings. We recommend:

```bash
# Disable password login (use SSH keys instead)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Regular backups

```bash
# Stop, backup, start
cd /opt/conduit
sudo docker compose down
sudo tar -czf ~/conduit-backup-$(date +%Y%m%d).tar.gz /opt/conduit /var/lib/docker/volumes/conduit_conduit-data
sudo docker compose up -d
```

### Monitor disk usage

Media files can grow over time. The `conduit.toml` has retention policies:
- Cached files (from other servers): cleaned after 30 days unused
- Local media: cleaned after 365 days unused
- Thumbnails: capped at 1GB
- Total media: capped at 10GB
