# 📞 Voice & Video Calls (TURN/STUN)

## How calls work in Matrix

Matrix supports voice and video calls. Here's how they connect:

```
Best case (direct):
Alice's phone  ←──── STUN ────→  Bob's phone
                  (peer-to-peer)

When direct fails (NAT/firewall):
Alice's phone  ←── TURN relay ──→  Bob's phone
                 (through your server)
```

### STUN vs TURN

| | STUN | TURN |
|---|------|------|
| **What** | Helps devices find each other | Relays traffic through the server |
| **When** | Works if both sides can connect directly | Used when direct connection fails |
| **Bandwidth** | None (just discovery) | Uses your server's bandwidth |
| **Port** | 3478 | 3478 (UDP), 5349 (TLS) |

## Configuration

The script configures Coturn (TURN/STUN server) with these URIs:

```
turn:your-matrix-host?transport=udp   ← Primary (fastest)
turn:your-matrix-host?transport=tcp   ← Fallback
stun:your-matrix-host                 ← Peer-to-peer discovery
```

### Why UDP first?

UDP is faster and uses less bandwidth — perfect for real-time audio/video. TCP is only used as a fallback when UDP is blocked.

### Why no TURNS (TLS)?

You might notice we don't include `turns:` URIs. This is intentional:

> Element and other clients **prefer TURNS over plain TURN** when both are available, forcing all traffic through TCP even when UDP works fine. This adds **100-200ms latency** to your calls — noticeable delays in real-time conversations.

Since the TURN authentication uses a shared secret (not passwords sent in clear text), the security benefit of TLS for TURN is minimal, while the performance cost is significant.

**In simple terms:** TURNS forces TCP (slower, higher latency) instead of UDP (fast, low latency). For real-time voice/video, UDP is much better.

## Certificates

Coturn uses TLS certificates from Caddy (Let's Encrypt). The script sets up automatic syncing:

1. Caddy gets/renews certificates automatically
2. A systemd watcher detects changes
3. Certificates are copied to Coturn
4. Coturn is restarted

You don't need to do anything — it's fully automated.

## Troubleshooting calls

### Calls don't connect at all
- Check if Coturn is running: `sudo docker compose ps coturn`
- Check if ports are open: `sudo ufw status | grep -E "3478|5349"`

### Calls connect but audio is choppy
- Check server bandwidth
- Calls relay through your server when direct connection fails
- A server closer to the users will have better performance

### Calls work on WiFi but not on mobile data
- Your mobile carrier might block TURN ports
- TCP fallback should handle this, but some carriers are aggressive
