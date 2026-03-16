# Admin Room Guide

The **Admin Room** is your control center for managing your Conduit Matrix server. The first account created during installation is automatically added to this room with full administrative privileges.

## What is the Admin Room?

The Admin Room is a special Matrix room where you can:
- Create and manage user accounts
- Toggle registration on/off
- Reset passwords
- Deactivate users
- View server statistics and diagnostics
- Manage rooms and media

All commands are sent as messages in the room, making server management as simple as sending a chat message.

## How to Find It

After logging in to Element (or any Matrix client) with your admin account:

1. Look for a room called **"Conduit Admin Room"** in your room list
2. It appears automatically — you don't need to create or join it
3. If you don't see it, try refreshing your client or logging out and back in

## Command Reference

All commands are sent as messages to the Admin Room. Replace `conduit` with your actual server name.

| Command | Description |
|---------|-------------|
| `@conduit:yourdomain.com help` | Show all available commands |
| `@conduit:yourdomain.com list-local-users` | List all users on your server |
| `@conduit:yourdomain.com create-user <username> <password>` | Create a new user account |
| `@conduit:yourdomain.com reset-password <user_id> <new_password>` | Reset a user's password |
| `@conduit:yourdomain.com deactivate-user <user_id>` | Deactivate a user account |
| `@conduit:yourdomain.com allow-registration true/false` | Enable or disable registration |
| `@conduit:yourdomain.com list-rooms` | List all rooms on your server |
| `@conduit:yourdomain.com list-media` | Show media storage statistics |
| `@conduit:yourdomain.com purge-media <mxc_uri>` | Delete specific media file |
| `@conduit:yourdomain.com show-config` | Display current server configuration |
| `@conduit:yourdomain.com memory-usage` | Show server memory usage |
| `@conduit:yourdomain.com clear-database-caches` | Clear database caches |
| `@conduit:yourdomain.com clear-service-caches` | Clear service caches |
| `@conduit:yourdomain.com disable-room <room_id>` | Disable a room |
| `@conduit:yourdomain.com enable-room <room_id>` | Re-enable a disabled room |

## Common Tasks

### Add a New User

```
@conduit:yourdomain.com create-user alice SecurePassword123
```

The user can then log in at https://app.element.io with:
- Username: `@alice:yourdomain.com`
- Password: `SecurePassword123`

### Reset a User's Password

```
@conduit:yourdomain.com reset-password @alice:yourdomain.com NewPassword456
```

### Enable Self-Registration

If you want to allow people to register themselves using the registration token:

```
@conduit:yourdomain.com allow-registration true
```

Then share your registration token (found in `/opt/conduit/CREDENTIALS.txt`) with users.

**Important:** Remember to close registration when done:

```
@conduit:yourdomain.com allow-registration false
```

### Deactivate a User

```
@conduit:yourdomain.com deactivate-user @spam-bot:yourdomain.com
```

### Check Server Statistics

```
@conduit:yourdomain.com memory-usage
@conduit:yourdomain.com list-local-users
@conduit:yourdomain.com list-rooms
```

## Multi-Client Management

The Admin Room works from **any Matrix client**:
- **Element Web:** https://app.element.io
- **Element Desktop:** Full desktop app (Windows/Mac/Linux)
- **Element Mobile:** iOS/Android apps
- **FluffyChat, SchildiChat, Nheko, etc.**

This means you can manage your server from your phone, tablet, or desktop — wherever you have your Matrix client.

## Password Recovery

If you forgot your admin password, you can reset it from the server without needing to log in:

```bash
sudo bash conduit-deploy.sh
# Choose: Services → Password Recovery (option p)
```

The script will:
1. Ask which account to reset
2. Ask for a new password
3. Temporarily enable emergency access
4. Reset the password via the Admin Room
5. Remove emergency access automatically

> **This is the only task that requires SSH access.** Everything else can be done from the Admin Room in your Matrix client.

## Security Notes

- **The first account created during installation is the only admin** — it gets automatic access to the Admin Room
- Additional accounts created via Admin Room are regular users (no admin privileges)
- Commands are logged in the room history
- Keep your admin account credentials secure
- Consider using a strong, unique password for admin accounts

## Troubleshooting

### Admin Room Not Showing Up

1. Log out and log back in to your Matrix client
2. Force refresh (Element Web: Ctrl+Shift+R or Cmd+Shift+R)
3. Check that your account was created during installation (it should be the first account)
4. If the room still doesn't appear, check server logs: `sudo docker logs conduit`

### Commands Not Working

- Make sure you're typing the full command exactly as shown
- Replace `yourdomain.com` with your actual server domain
- User IDs must include the `@` prefix and `:domain` suffix (e.g., `@alice:yourdomain.com`)
- Check that the Conduit container is running: `sudo docker ps`

### Registration Token

If you need to find your registration token:

```bash
cat /opt/conduit/CREDENTIALS.txt
```

Or check the `.env` file:

```bash
sudo cat /opt/conduit/.env | grep REGISTRATION_TOKEN
```

---

**Next Steps:**
- [After Install Guide](after-install.md) — What to do after installation
- [Troubleshooting](troubleshooting.md) — Common issues and solutions
- [FAQ](faq.md) — Frequently asked questions
