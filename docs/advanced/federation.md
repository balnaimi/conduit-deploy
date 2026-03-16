# 🌍 Federation

## What is Federation?

Federation means your server can **talk to other Matrix servers**. It's like email — you don't need a Gmail account to email someone at Gmail.

```
@alice:your-server.com  ←→  @bob:matrix.org
        ↕                         ↕
   Your Server            matrix.org server
```

## How it works

1. Alice on your server sends a message to Bob on matrix.org
2. Your server connects to matrix.org on **port 8448**
3. The message is delivered (encrypted end-to-end)
4. Bob sees the message in his app

## Is it automatic?

**Yes!** Federation is enabled by default. As long as:
- Port 8448 is open (the script does this)
- DNS is configured correctly
- Your server has a valid TLS certificate

## Can I disable it?

If you want a completely private server (no outside communication):

Edit `/opt/conduit/.env` or the docker-compose environment:
```
CONDUIT_ALLOW_FEDERATION: "false"
```

Then restart:
```bash
cd /opt/conduit && sudo docker compose up -d conduit
```

## Testing federation

Use the official federation tester:

```
https://federationtester.matrix.org/api/report?server_name=example.com
```

Replace `example.com` with your actual domain.

## Trusted servers

By default, your server trusts `matrix.org` for key verification. This is the standard configuration and recommended for most setups.
