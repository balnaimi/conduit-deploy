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

1. Share the **registration token** with them (Menu → Registration → Show token)
2. They download an app → Sign up → Enter your domain as homeserver
3. Use the token when asked

> **Tip:** You can also create accounts from the script directly (Menu → Registration → Create account). The script collects the username and password first, then briefly opens registration, creates the account, and closes registration again — all in one step.

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

Now that everything works, do these important steps:

### Close registration

So random people can't create accounts on your server:

```bash
sudo bash conduit-deploy.sh
# Choose 4 → 2 (Close registration)
```

### Save your credentials

The script saved credentials to `/opt/conduit/CREDENTIALS.txt`. Copy them somewhere safe (like a password manager), then delete the file:

```bash
sudo rm /opt/conduit/CREDENTIALS.txt
```

> **Don't worry if you lose it** — your registration token is also stored in `/opt/conduit/.env` and can be viewed anytime from the Health Check menu.

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

Each backup saves:
- All messages, accounts, rooms, and encryption keys
- Media files and configuration
- **Pinned Docker image versions** (SHA256 digests) — so restoring gives you back the exact same software, not a newer version

Backups are stored at `/opt/conduit-backups/` (separate from your installation — survives even uninstall).

You can restore on the same server or migrate to a new one: **Services → Restore from backup**

> 📖 See the full [Backup & Restore Walkthrough](https://balnaimi.github.io/conduit-deploy/walkthrough.html#backup) for step-by-step instructions.

---

**Need help?** Check the [FAQ](faq.md) or [Troubleshooting](troubleshooting.md) guide.
