#!/bin/bash
# ─────────────────────────────────────────────
# Conduit Matrix Server - Quick Setup Script
# Run on a fresh VPS (Debian 13 / Ubuntu 24.04)
# ─────────────────────────────────────────────

set -e

echo "🚀 Conduit Matrix Server Setup"
echo "================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo bash setup.sh)"
    exit 1
fi

# Get domain from user
read -p "Enter your domain (e.g. matrix.majlis7.net): " DOMAIN
read -p "Enter your email (for Let's Encrypt): " EMAIL

# Generate secrets
REG_TOKEN=$(openssl rand -hex 32)
TURN_SECRET=$(openssl rand -hex 32)

echo ""
echo "📋 Configuration:"
echo "  Domain: $DOMAIN"
echo "  Registration Token: $REG_TOKEN"
echo "  TURN Secret: $TURN_SECRET"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi

# ─────────────────────────────────────────────
# 1. Install Docker
# ─────────────────────────────────────────────
echo "📦 Installing Docker..."
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# ─────────────────────────────────────────────
# 2. Setup firewall (ufw)
# ─────────────────────────────────────────────
echo "🔥 Configuring firewall..."
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp       # SSH
ufw allow 80/tcp       # HTTP (Let's Encrypt)
ufw allow 443/tcp      # HTTPS (Matrix)
ufw allow 8448/tcp     # Matrix Federation
ufw allow 3478/tcp     # TURN
ufw allow 3478/udp     # TURN
ufw allow 5349/tcp     # TURN TLS
ufw allow 5349/udp     # TURN TLS
ufw allow 49152:49252/udp  # TURN relay range
echo "y" | ufw enable

# ─────────────────────────────────────────────
# 3. Create project directory
# ─────────────────────────────────────────────
echo "📁 Setting up project..."
mkdir -p /opt/conduit
cd /opt/conduit

# ─────────────────────────────────────────────
# 4. Create .env file
# ─────────────────────────────────────────────
cat > .env << EOF
SERVER_NAME=$DOMAIN
REGISTRATION_TOKEN=$REG_TOKEN
TURN_SECRET=$TURN_SECRET
EOF

# ─────────────────────────────────────────────
# 5. Update turnserver.conf with actual values
# ─────────────────────────────────────────────
sed -i "s/CHANGE_ME_SERVER_NAME/$DOMAIN/g" turnserver.conf
sed -i "s/CHANGE_ME_TURN_SECRET/$TURN_SECRET/g" turnserver.conf

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Point DNS: $DOMAIN → $(curl -s ifconfig.me)"
echo "  2. Copy docker-compose.yml, Caddyfile, turnserver.conf to /opt/conduit/"
echo "  3. cd /opt/conduit && docker compose up -d"
echo "  4. Wait 30 seconds, then test: curl https://$DOMAIN/_matrix/client/versions"
echo ""
echo "🔑 Save these credentials:"
echo "  Registration Token: $REG_TOKEN"
echo "  TURN Secret: $TURN_SECRET"
echo ""
echo "📱 Connect with Element/SchildiChat:"
echo "  Homeserver: https://$DOMAIN"
echo "  Use registration token when signing up"
