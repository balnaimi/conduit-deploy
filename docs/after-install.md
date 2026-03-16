# 📱 After Installation

Your server is running! Here's what to do next.

## 1. Download an app

Matrix works with many apps. Pick one:

| App | Why choose it | iOS | Android | Desktop |
|-----|--------------|-----|---------|---------|
| **Element** | Most popular, all features | [Download](https://apps.apple.com/app/element-messenger/id1083446067) | [Download](https://play.google.com/store/apps/details?id=im.vector.app) | [Download](https://element.io/download) |
| **SchildiChat** | Nicer looking, based on Element | [Download](https://apps.apple.com/app/schildichat/id1634348070) | [Download](https://play.google.com/store/apps/details?id=de.spiritcroc.riotx) | [Download](https://schildi.chat/desktop/) |
| **FluffyChat** | Simple and lightweight | [Download](https://apps.apple.com/app/fluffychat/id1551469600) | [Download](https://play.google.com/store/apps/details?id=chat.fluffy.fluffychat) | — |

> **Recommendation:** Start with **Element** — it has the best compatibility.

## 2. Sign in

1. Open the app
2. Tap **"Sign in"**
3. Look for **"Homeserver"** and change it to your domain:
   - Mode 1: `example.com`
   - Mode 2: `chat.example.com`
4. Enter the username and password you created
5. You're in! 🎉

## 3. Verify your device

After signing in, the app will ask you to **verify your session**. This sets up end-to-end encryption.

- If this is your first device: it will ask you to create a **security key** or **security phrase**
- **Save this somewhere safe!** You'll need it to verify future devices

> **Why?** This is what makes your messages truly private. Not even your server can read them.

## 4. Invite people

### If they'll use your server:

You manage accounts via the **Admin Room** in Element:

1. Find the **"Conduit Admin Room"** in your room list (it appears automatically)
2. Type: `@conduit:yourdomain.com create-user alice SecurePassword123`
3. Share the username and password with the person
4. They can log in at https://app.element.io

> **See the full guide:** [Admin Room documentation](admin-room.md)

### If they're on another Matrix server:

Just message them directly! Matrix is **federated** — you can talk to anyone on any Matrix server.

Their address will look like: `@theirname:matrix.org` (or whatever server they're on)

## 5. Make a group chat

1. Open the app
2. Tap the **+** button → **New Room**
3. Name it (e.g. "Family Chat")
4. Toggle **encryption ON** (recommended)
5. Invite people by their Matrix address

## 6. Secure your server

Your server is already secure by default:

- ✅ **Registration is closed** — only you can create accounts via the Admin Room
- ✅ **HTTPS everywhere** — all traffic is encrypted
- ✅ **Firewall configured** — only necessary ports are open

### Save your credentials

The script saved credentials to `/opt/conduit/CREDENTIALS.txt`. Copy them somewhere safe (like a password manager), then delete the file:

```bash
sudo rm /opt/conduit/CREDENTIALS.txt
```

> **Forgot your admin password?** Run the script again → **Services → Password Recovery** (option `p`). This resets any account's password from the server without needing to log in.

### Set up SSH keys (optional but recommended)

If you're still using passwords to log into your server, consider switching to SSH keys. It's much more secure.

## 7. Tell your server admin (that's you!)

Here are things you should know as the server operator:

| Task | How often | How |
|------|-----------|-----|
| Check server health | Weekly | Menu → Health Check |
| Update containers | Monthly | Menu → Services → Update |
| Check disk space | Monthly | Health Check shows this |
| Review logs | When needed | Menu → Services → Logs |

The server handles most things automatically:
- ✅ TLS certificates renew automatically
- ✅ Security updates install automatically
- ✅ Services restart automatically if they crash

## 8. Backups

Take regular backups from the menu: **Services → Backup (with version pinning)**

Each backup exports Docker volume data and saves:
- All messages, accounts, rooms, and encryption keys (from database volume)
- Media files — optional, you can exclude to save space (accounts/messages still saved without media)
- Configuration and TLS certificates
- **Pinned Docker image versions** (SHA256 digests) — so restoring gives you back the exact same software, not a newer version

Backups are stored at `/opt/conduit-backups/` (separate from your installation — survives even uninstall).

You can restore on the same server or migrate to a new one: **Services → Restore from backup**

> 📖 See the full [Backup & Restore Walkthrough](https://balnaimi.github.io/conduit-deploy/walkthrough.html#backup) for step-by-step instructions.

---

**Need help?** Check the [FAQ](faq.md) or [Troubleshooting](troubleshooting.md) guide.
