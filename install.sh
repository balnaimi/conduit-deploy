#!/usr/bin/env bash
#
# ╔═══════════════════════════════════════════════════╗
# ║  Matrix Conduit Server — Interactive Manager      ║
# ║  Deploy and manage your own Matrix server         ║
# ╚═══════════════════════════════════════════════════╝
#
# Requirements: Fresh Debian 13 VPS with root or sudo access
# Usage: sudo bash install.sh  (or as root: bash install.sh)
#

set -euo pipefail

# ─── Config ───
INSTALL_DIR="/opt/conduit"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
ENV_FILE="$INSTALL_DIR/.env"
CREDS_FILE="$INSTALL_DIR/CREDENTIALS.txt"

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Helpers ───
info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
error()   { echo -e "${RED}❌${NC} $1"; }
step()    { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }
ask()     { echo -en "${BOLD}$1${NC} "; }

separator() {
    echo -e "${DIM}───────────────────────────────────────────────${NC}"
}

# ─── Privilege helper ───
# Runs command as root (directly if root, via sudo otherwise)
SUDO=""
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
fi

press_enter() {
    echo
    ask "Press Enter to continue..."
    read -r
}

# ─── Load existing config ───
load_config() {
    DOMAIN=""
    VPS_IP=""
    TURN_SECRET=""
    REGISTRATION_TOKEN=""

    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE" 2>/dev/null || true
        DOMAIN="${SERVER_NAME:-}"
        VPS_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
    fi
}

# ─── Header ───
show_header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   🏠 Matrix Conduit Server Manager        ║"
    echo "  ║   Your own private messaging server       ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE" 2>/dev/null || true
        echo -e "  ${DIM}Domain: ${GREEN}${SERVER_NAME:-not set}${NC}"
        
        # Quick status
        if command -v docker &>/dev/null && $SUDO docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' conduit 2>/dev/null | grep -q "running"; then
            echo -e "  ${DIM}Status: ${GREEN}● Running${NC}"
        elif [ -f "$COMPOSE_FILE" ]; then
            echo -e "  ${DIM}Status: ${RED}● Stopped${NC}"
        else
            echo -e "  ${DIM}Status: ${YELLOW}● Not installed${NC}"
        fi
    else
        echo -e "  ${DIM}Status: ${YELLOW}● Not installed${NC}"
    fi
    echo
}

# ═══════════════════════════════════════════════
#  MENU 1: PREPARE
# ═══════════════════════════════════════════════
menu_prepare() {
    show_header
    step "📋 Pre-Installation Checklist"

    # Ask domain
    echo -e "  ${DIM}This will tell you exactly what to set up before installing.${NC}"
    echo
    ask "Your domain name (e.g. example.com):"
    read -r PREP_DOMAIN
    if [ -z "$PREP_DOMAIN" ]; then
        error "Domain is required"
        press_enter
        return
    fi

    # Detect IP
    PREP_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || echo "YOUR_VPS_IP")

    # Detect IPv6
    PREP_IPV6=$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print $2}' | cut -d/ -f1 | head -1)

    echo
    separator
    echo -e "\n${BOLD}${GREEN}Before you install, complete these steps:${NC}\n"

    # ─── VPS Requirements ───
    echo -e "  ${BOLD}🖥️  VPS Requirements:${NC}"
    echo -e "     • Debian 13 (or Ubuntu 22.04+)"
    echo -e "     • Minimum 512MB RAM (1GB+ recommended)"
    echo -e "     • 10GB+ free disk"
    echo -e "     • SSH access with root or sudo privileges"
    echo -e "     • Ports 80, 443, 8448, 3478, 5349 NOT blocked by provider"
    echo

    # ─── DNS Records ───
    echo -e "  ${BOLD}🌐 DNS Records (add these in your DNS provider):${NC}"
    echo
    echo -e "     ${CYAN}1.${NC} ${BOLD}A Record${NC} — Points to your server"
    echo -e "        Name:  ${GREEN}matrix${NC}"
    echo -e "        Value: ${GREEN}${PREP_IP}${NC}"
    echo -e "        Proxy: ${RED}OFF (DNS Only)${NC}"
    echo

    echo -e "     ${CYAN}2.${NC} ${BOLD}SRV Record${NC} — Federation discovery"
    echo -e "        Name:     ${GREEN}_matrix._tcp${NC}"
    echo -e "        Target:   ${GREEN}matrix.${PREP_DOMAIN}${NC}"
    echo -e "        Port:     ${GREEN}443${NC}"
    echo -e "        Priority: 0  Weight: 1"
    echo

    if [ -n "$PREP_IPV6" ]; then
        echo -e "     ${CYAN}3.${NC} ${BOLD}AAAA Record${NC} — IPv6 (detected on this server)"
        echo -e "        Name:  ${GREEN}matrix${NC}"
        echo -e "        Value: ${GREEN}${PREP_IPV6}${NC}"
        echo -e "        Proxy: ${RED}OFF (DNS Only)${NC}"
        echo
    else
        echo -e "     ${CYAN}3.${NC} ${BOLD}AAAA Record${NC} — IPv6 (optional)"
        echo -e "        ${DIM}Enable IPv6 on your VPS first, then add this record${NC}"
        echo
    fi

    # ─── .well-known delegation ───
    echo -e "  ${BOLD}🔗 .well-known Delegation${NC} (required for clean usernames):"
    echo
    echo -e "     Your usernames will be ${GREEN}@user:${PREP_DOMAIN}${NC} but the server"
    echo -e "     runs at ${GREEN}matrix.${PREP_DOMAIN}${NC}. To link them, your root domain"
    echo -e "     needs to serve a small JSON response."
    echo
    echo -e "     ${CYAN}Option A:${NC} ${BOLD}Root domain has NO existing website${NC}"
    echo -e "        → The installer handles everything automatically!"
    echo -e "        → Just point ${GREEN}${PREP_DOMAIN}${NC} (A record) to your server IP: ${GREEN}${PREP_IP}${NC}"
    echo
    echo -e "     ${CYAN}Option B:${NC} ${BOLD}Root domain has an existing website${NC}"
    echo -e "        → Add this to your existing web server:"
    echo
    echo -e "        ${BOLD}Nginx:${NC}"
    echo -e "        ${DIM}location /.well-known/matrix/server {"
    echo -e "            return 200 '{\"m.server\": \"matrix.${PREP_DOMAIN}:443\"}';"
    echo -e "            add_header Content-Type application/json;"
    echo -e "        }"
    echo -e "        location /.well-known/matrix/client {"
    echo -e "            return 200 '{\"m.homeserver\": {\"base_url\": \"https://matrix.${PREP_DOMAIN}\"}}';"
    echo -e "            add_header Content-Type application/json;"
    echo -e "            add_header Access-Control-Allow-Origin *;"
    echo -e "        }${NC}"
    echo
    echo -e "        ${BOLD}Apache:${NC}"
    echo -e "        ${DIM}# Create /.well-known/matrix/server with:"
    echo -e "        {\"m.server\": \"matrix.${PREP_DOMAIN}:443\"}"
    echo -e "        # Create /.well-known/matrix/client with:"
    echo -e "        {\"m.homeserver\": {\"base_url\": \"https://matrix.${PREP_DOMAIN}\"}}${NC}"
    echo
    echo -e "        ${BOLD}Traefik:${NC}"
    echo -e "        ${DIM}# Use a middleware or small container to serve the JSON${NC}"

    echo
    separator
    echo
    echo -e "  ${BOLD}📱 Apps to download:${NC}"
    echo -e "     • ${GREEN}Element${NC} — iOS / Android / Web (most popular)"
    echo -e "     • ${GREEN}SchildiChat${NC} — iOS / Android (nicer UI)"
    echo -e "     • ${GREEN}FluffyChat${NC} — iOS / Android (lightweight)"

    echo
    separator
    echo -e "\n  ${BOLD}${YELLOW}Complete the above steps, then come back and choose 'Install'.${NC}\n"

    press_enter
}

# ═══════════════════════════════════════════════
#  MENU 2: INSTALL
# ═══════════════════════════════════════════════
menu_install() {
    show_header

    # Check if already installed
    if [ -f "$COMPOSE_FILE" ]; then
        warn "Conduit is already installed at $INSTALL_DIR"
        ask "Reinstall? This will OVERWRITE config files. [y/N]"
        read -r reply
        [[ "$reply" =~ ^[Yy]$ ]] || return
    fi

    # ─── Pre-flight ───
    step "Pre-flight Checks"

    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        error "Root or sudo access required: ${BOLD}sudo bash install.sh${NC}"
        press_enter
        return
    fi

    if ! grep -qi 'debian\|ubuntu' /etc/os-release 2>/dev/null; then
        warn "This script is tested on Debian 13. Other distros may work."
        ask "Continue anyway? [y/N]"
        read -r reply
        [[ "$reply" =~ ^[Yy]$ ]] || return
    fi

    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_DISK=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
    
    if [ "$TOTAL_RAM" -lt 512 ]; then
        error "Need at least 512MB RAM (you have ${TOTAL_RAM}MB)"
        press_enter
        return
    fi
    success "RAM: ${TOTAL_RAM}MB | Free disk: ${TOTAL_DISK}GB"

    # ─── Gather info ───
    step "Configuration"

    echo -e "  ${DIM}Example: majlis7.net, example.com${NC}"
    ask "Your domain name:"
    read -r DOMAIN
    [ -z "$DOMAIN" ] && { error "Domain is required"; press_enter; return; }

    DETECTED_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
    if [ -n "$DETECTED_IP" ]; then
        ask "VPS public IP [${GREEN}${DETECTED_IP}${NC}]:"
        read -r VPS_IP
        VPS_IP=${VPS_IP:-$DETECTED_IP}
    else
        ask "VPS public IP:"
        read -r VPS_IP
    fi
    [ -z "$VPS_IP" ] && { error "VPS IP is required"; press_enter; return; }

    # Well-known delegation
    echo
    echo -e "  ${BOLD}📌 .well-known Delegation${NC}"
    echo -e "  ${DIM}Your usernames will be @user:${DOMAIN} but the server runs at matrix.${DOMAIN}${NC}"
    echo -e "  ${DIM}The root domain needs to tell clients where to find the server.${NC}"
    echo
    echo -e "  ${CYAN}A${NC}) Root domain (${DOMAIN}) has ${BOLD}NO existing website${NC} — Caddy handles it"
    echo -e "  ${CYAN}B${NC}) Root domain (${DOMAIN}) has ${BOLD}an existing website${NC} — I'll give you instructions"
    echo
    ask "Choose [A/B]:"
    read -r WELLKNOWN_MODE
    WELLKNOWN_MODE=${WELLKNOWN_MODE:-A}
    WELLKNOWN_MODE=$(echo "$WELLKNOWN_MODE" | tr '[:lower:]' '[:upper:]')

    if [[ "$WELLKNOWN_MODE" == "B" ]]; then
        echo
        echo -e "  ${BOLD}${YELLOW}Add this to your existing web server for ${DOMAIN}:${NC}"
        echo
        echo -e "  ${BOLD}Nginx:${NC}"
        echo -e "  ${DIM}location /.well-known/matrix/server {"
        echo -e "      return 200 '{\"m.server\": \"matrix.${DOMAIN}:443\"}';"
        echo -e "      add_header Content-Type application/json;"
        echo -e "  }"
        echo -e "  location /.well-known/matrix/client {"
        echo -e "      return 200 '{\"m.homeserver\": {\"base_url\": \"https://matrix.${DOMAIN}\"}}';"
        echo -e "      add_header Content-Type application/json;"
        echo -e "      add_header Access-Control-Allow-Origin *;"
        echo -e "  }${NC}"
        echo
        echo -e "  ${BOLD}Apache:${NC}"
        echo -e "  ${DIM}Create files at: /.well-known/matrix/server and /.well-known/matrix/client${NC}"
        echo
        echo -e "  ${BOLD}Traefik:${NC}"
        echo -e "  ${DIM}Use a middleware or small container to serve the JSON responses${NC}"
        echo
        warn "Add the config above to your web server, then press Enter to continue."
        ask "Press Enter when ready (or Ctrl+C to cancel)..."
        read -r
    fi

    echo
    echo -e "  ${DIM}Default: 100MB. Matrix supports up to 1GB.${NC}"
    ask "Max upload size in MB [100]:"
    read -r MAX_UPLOAD_MB
    MAX_UPLOAD_MB=${MAX_UPLOAD_MB:-100}
    MAX_UPLOAD_BYTES=$((MAX_UPLOAD_MB * 1024 * 1024))

    REGISTRATION_TOKEN=$(openssl rand -hex 32)
    TURN_SECRET=$(openssl rand -hex 32)

    separator
    echo
    echo -e "  ${BOLD}Summary:${NC}"
    echo -e "  Domain:      ${GREEN}${DOMAIN}${NC}"
    echo -e "  Matrix URL:  ${GREEN}https://matrix.${DOMAIN}${NC}"
    echo -e "  VPS IP:      ${GREEN}${VPS_IP}${NC}"
    echo -e "  Max upload:  ${GREEN}${MAX_UPLOAD_MB}MB${NC}"
    if [[ "$WELLKNOWN_MODE" == "A" ]]; then
        echo -e "  .well-known: ${GREEN}Caddy (automatic)${NC}"
    else
        echo -e "  .well-known: ${YELLOW}External (your web server)${NC}"
    fi
    echo
    ask "Start installation? [Y/n]"
    read -r confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && return

    # ─── Install Docker ───
    step "Installing Docker"
    if command -v docker &>/dev/null; then
        success "Docker already installed"
    else
        info "Installing Docker..."
        curl -fsSL https://get.docker.com | $SUDO sh
        $SUDO systemctl enable --now docker
        success "Docker installed"
    fi
    docker compose version &>/dev/null || { error "Docker Compose v2 not found"; press_enter; return; }
    success "Docker Compose available"

    # ─── Firewall ───
    step "Configuring Firewall"
    if ! command -v ufw &>/dev/null; then
        $SUDO apt-get install -y -qq ufw >/dev/null 2>&1
    fi
    $SUDO ufw --force reset >/dev/null 2>&1
    $SUDO ufw default deny incoming >/dev/null 2>&1
    $SUDO ufw default allow outgoing >/dev/null 2>&1
    $SUDO ufw allow 22/tcp   comment 'SSH' >/dev/null 2>&1
    $SUDO ufw allow 80/tcp   comment 'HTTP' >/dev/null 2>&1
    $SUDO ufw allow 443/tcp  comment 'HTTPS' >/dev/null 2>&1
    $SUDO ufw allow 8448/tcp comment 'Matrix Federation' >/dev/null 2>&1
    $SUDO ufw allow 3478     comment 'TURN STUN' >/dev/null 2>&1
    $SUDO ufw allow 5349     comment 'TURN TLS/DTLS' >/dev/null 2>&1
    $SUDO ufw allow 49152:65535/udp comment 'Media Relay' >/dev/null 2>&1
    $SUDO ufw --force enable >/dev/null 2>&1
    success "Firewall configured"

    # ─── Hardening ───
    step "Server Hardening"

    # Swap
    if [ "$TOTAL_RAM" -lt 2048 ] && ! swapon --show 2>/dev/null | grep -q "/swapfile"; then
        $SUDO fallocate -l 2G /swapfile && $SUDO chmod 600 /swapfile
        $SUDO mkswap /swapfile >/dev/null 2>&1 && $SUDO swapon /swapfile
        grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" | $SUDO tee -a /etc/fstab > /dev/null
        success "Swap 2GB configured"
    else
        success "Swap OK"
    fi

    # Fail2ban
    if ! command -v fail2ban-client &>/dev/null; then
        $SUDO apt-get install -y -qq fail2ban >/dev/null 2>&1
    fi
    $SUDO systemctl enable --now fail2ban >/dev/null 2>&1
    success "Fail2ban active"

    # Disable exim4
    if systemctl is-active exim4 &>/dev/null; then
        $SUDO systemctl stop exim4 && $SUDO systemctl disable exim4 >/dev/null 2>&1
        success "Disabled exim4"
    fi

    # Auto updates
    dpkg -l | grep -q unattended-upgrades || $SUDO apt-get install -y -qq unattended-upgrades >/dev/null 2>&1
    success "Auto security updates enabled"

    # ─── Config files ───
    step "Creating Configuration Files"
    $SUDO mkdir -p "$INSTALL_DIR/certs"
    cd "$INSTALL_DIR"

    # .env
    $SUDO tee .env > /dev/null << EOF
SERVER_NAME=${DOMAIN}
TURN_SECRET=${TURN_SECRET}
REGISTRATION_TOKEN=${REGISTRATION_TOKEN}
PUBLIC_IP=${VPS_IP}
EOF
    success "Created .env"

    # docker-compose.yml
    $SUDO tee docker-compose.yml > /dev/null << 'YAML'
###############################################
# Matrix Conduit Server
# Components: Conduit + Caddy (TLS) + Coturn (TURN)
#
# Caddy is the ONLY container with public ports.
# Conduit has NO port mapping — prevents Docker
# from bypassing ufw/iptables firewall rules.
###############################################

services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8448:8448"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    networks:
      - matrix

  conduit:
    image: matrixconduit/matrix-conduit:latest
    container_name: conduit
    restart: unless-stopped
    env_file: .env
    environment:
      CONDUIT_CONFIG: /etc/conduit.toml
      CONDUIT_SERVER_NAME: ${SERVER_NAME}
      CONDUIT_DATABASE_BACKEND: rocksdb
      CONDUIT_DATABASE_PATH: /var/lib/matrix-conduit
      CONDUIT_PORT: 6167
      CONDUIT_ADDRESS: 0.0.0.0
      CONDUIT_MAX_REQUEST_SIZE: 104857600
      CONDUIT_ALLOW_REGISTRATION: "true"
      CONDUIT_REGISTRATION_TOKEN: ${REGISTRATION_TOKEN}
      CONDUIT_ALLOW_FEDERATION: "true"
      CONDUIT_ALLOW_ENCRYPTION: "true"
      CONDUIT_ALLOW_ROOM_CREATION: "true"
      CONDUIT_TRUSTED_SERVERS: '["matrix.org"]'
      # UDP first (fastest), TCP fallback — do NOT add turns: (Element prefers TLS over UDP)
      CONDUIT_TURN_URIS: '["turn:matrix.${SERVER_NAME}?transport=udp","turn:matrix.${SERVER_NAME}?transport=tcp","stun:matrix.${SERVER_NAME}"]'
      CONDUIT_TURN_SECRET: ${TURN_SECRET}
      CONDUIT_WELL_KNOWN_CLIENT: "https://matrix.${SERVER_NAME}"
      CONDUIT_WELL_KNOWN_SERVER: "matrix.${SERVER_NAME}:443"
    volumes:
      - conduit-data:/var/lib/matrix-conduit
      - ./conduit.toml:/etc/conduit.toml:ro
    networks:
      - matrix
    depends_on:
      - caddy

  coturn:
    image: coturn/coturn:alpine
    container_name: coturn
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./turnserver.conf:/etc/turnserver.conf:ro
      - ./certs:/etc/turn-certs:ro
    command: ["-c", "/etc/turnserver.conf"]

volumes:
  conduit-data:
  caddy-data:
  caddy-config:

networks:
  matrix:
    driver: bridge
YAML

    # Fix MAX_REQUEST_SIZE with actual value
    $SUDO sed -i "s/CONDUIT_MAX_REQUEST_SIZE: 104857600/CONDUIT_MAX_REQUEST_SIZE: ${MAX_UPLOAD_BYTES}/" docker-compose.yml
    success "Created docker-compose.yml"

    # Caddyfile
    if [[ "$WELLKNOWN_MODE" == "A" ]]; then
        # Mode A: Caddy serves both Matrix + .well-known on root domain
        $SUDO tee Caddyfile > /dev/null << EOF
matrix.${DOMAIN}:443 {
    reverse_proxy conduit:6167
}

matrix.${DOMAIN}:8448 {
    reverse_proxy conduit:6167
}

${DOMAIN}:443 {
    header /.well-known/matrix/* Content-Type application/json
    header /.well-known/matrix/client Access-Control-Allow-Origin *

    respond /.well-known/matrix/server \`{"m.server": "matrix.${DOMAIN}:443"}\` 200
    respond /.well-known/matrix/client \`{"m.homeserver": {"base_url": "https://matrix.${DOMAIN}"}}\` 200

    respond "Not Found" 404
}
EOF
    else
        # Mode B: Only Matrix subdomain, .well-known handled externally
        $SUDO tee Caddyfile > /dev/null << EOF
matrix.${DOMAIN}:443 {
    reverse_proxy conduit:6167
}

matrix.${DOMAIN}:8448 {
    reverse_proxy conduit:6167
}
EOF
    fi
    success "Created Caddyfile"

    # turnserver.conf
    $SUDO tee turnserver.conf > /dev/null << EOF
# Coturn TURN/STUN Configuration
listening-port=3478
tls-listening-port=5349

# TLS Certificates
cert=/etc/turn-certs/turn.crt
pkey=/etc/turn-certs/turn.key

# Listen on IPv4 + IPv6
listening-ip=0.0.0.0
listening-ip=::

# Relay
min-port=49152
max-port=65535
relay-ip=${VPS_IP}
external-ip=${VPS_IP}

# Authentication (shared secret with Conduit)
use-auth-secret
static-auth-secret=${TURN_SECRET}
realm=matrix.${DOMAIN}

fingerprint

# Security — block private IPs
no-multicast-peers
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
no-cli

log-file=stdout
EOF
    success "Created turnserver.conf"

    # conduit.toml
    $SUDO tee conduit.toml > /dev/null << 'EOF'
[global]

[global.media]
backend = "filesystem"

[[global.media.retention]]
space = "10GB"

[[global.media.retention]]
scope = "remote"
accessed = "30d"
created = "90d"

[[global.media.retention]]
scope = "local"
accessed = "365d"

[[global.media.retention]]
scope = "thumbnail"
space = "1GB"
EOF
    success "Created conduit.toml"

    # ─── Start ───
    step "Starting Services"
    $SUDO docker compose pull 2>&1 | grep -E 'Pull|Done|Error' || true
    $SUDO docker compose up -d 2>&1
    
    info "Waiting for Let's Encrypt certificate (up to 60s)..."
    for i in $(seq 1 12); do
        sleep 5
        if curl -s -o /dev/null -w "%{http_code}" "https://matrix.${DOMAIN}/_matrix/client/versions" 2>/dev/null | grep -q "200"; then
            success "HTTPS is working!"
            break
        fi
        echo -n "."
    done
    echo

    # Copy TLS certs for Coturn
    CERT_DIR="/var/lib/docker/volumes/conduit_caddy-data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/matrix.${DOMAIN}"
    if [ -d "$CERT_DIR" ]; then
        $SUDO cp "$CERT_DIR/matrix.${DOMAIN}.crt" "$INSTALL_DIR/certs/turn.crt"
        $SUDO cp "$CERT_DIR/matrix.${DOMAIN}.key" "$INSTALL_DIR/certs/turn.key"
        $SUDO chmod 644 "$INSTALL_DIR/certs/turn."*
        $SUDO docker compose restart coturn >/dev/null 2>&1
        success "TLS certificates synced to Coturn"
    else
        warn "TLS certs not ready yet — Coturn will work without TLS."
        warn "Re-run Health Check later to verify."
    fi

    # Cert auto-sync watcher
    info "Setting up TLS cert auto-sync..."
    $SUDO tee /etc/systemd/system/turn-cert-sync.path > /dev/null << EOF
[Unit]
Description=Watch Caddy TLS certs for changes

[Path]
PathChanged=${CERT_DIR}/matrix.${DOMAIN}.crt

[Install]
WantedBy=multi-user.target
EOF

    $SUDO tee /etc/systemd/system/turn-cert-sync.service > /dev/null << EOF
[Unit]
Description=Sync TLS certs from Caddy to Coturn

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cp "${CERT_DIR}/matrix.${DOMAIN}.crt" "${INSTALL_DIR}/certs/turn.crt"; cp "${CERT_DIR}/matrix.${DOMAIN}.key" "${INSTALL_DIR}/certs/turn.key"; chmod 644 ${INSTALL_DIR}/certs/turn.*; docker restart coturn'
EOF
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable --now turn-cert-sync.path >/dev/null 2>&1
    success "TLS cert auto-sync active"

    # iptables UDP 443 → 5349
    if ! $SUDO iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "udp dpt:443.*5349"; then
        $SUDO iptables -t nat -A PREROUTING -p udp --dport 443 -j REDIRECT --to-port 5349
        $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iptables-persistent >/dev/null 2>&1
        $SUDO netfilter-persistent save >/dev/null 2>&1
        success "UDP 443 → Coturn redirect configured"
    fi

    # Save credentials
    $SUDO tee "$CREDS_FILE" > /dev/null << EOF
═══════════════════════════════════════════
  Matrix Conduit Server Credentials
  Generated: $(date)
═══════════════════════════════════════════

Domain:             ${DOMAIN}
Matrix URL:         https://matrix.${DOMAIN}
VPS IP:             ${VPS_IP}

Registration Token: ${REGISTRATION_TOKEN}
TURN Secret:        ${TURN_SECRET}

Install directory:  ${INSTALL_DIR}

⚠️  DELETE THIS FILE after saving credentials!
═══════════════════════════════════════════
EOF
    $SUDO chmod 600 "$CREDS_FILE"

    # ─── Done ───
    step "Installation Complete! 🎉"
    echo -e "  ${GREEN}Your Matrix server is running at:${NC}"
    echo -e "  ${BOLD}https://matrix.${DOMAIN}${NC}"
    echo
    echo -e "  ${BOLD}Registration Token:${NC}"
    echo -e "  ${YELLOW}${REGISTRATION_TOKEN}${NC}"
    echo
    echo -e "  ${DIM}Credentials saved to: ${CREDS_FILE}${NC}"
    echo
    warn "Registration is currently OPEN. Use the menu to close it after creating accounts."

    press_enter
}

# ═══════════════════════════════════════════════
#  MENU 3: HEALTH CHECK
# ═══════════════════════════════════════════════
menu_healthcheck() {
    show_header
    step "🔍 Health Check"

    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Conduit is not installed. Run Install first."
        press_enter
        return
    fi

    load_config
    local all_ok=true
    local issues=()

    # ─── Services ───
    echo -e "  ${BOLD}Services:${NC}"
    for svc in conduit caddy coturn; do
        if $SUDO docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' "$svc" 2>/dev/null | grep -q "running"; then
            success "  $svc is running"
        else
            error "  $svc is NOT running"
            all_ok=false
            issues+=("$svc is down")
        fi
    done
    echo

    # ─── HTTPS ───
    echo -e "  ${BOLD}Connectivity:${NC}"
    if [ -n "$DOMAIN" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://matrix.${DOMAIN}/_matrix/client/versions" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            success "  HTTPS working (matrix.${DOMAIN})"
        else
            error "  HTTPS failed (HTTP $HTTP_CODE)"
            all_ok=false
            issues+=("HTTPS not working")
        fi

        FED_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://matrix.${DOMAIN}:8448/_matrix/client/versions" 2>/dev/null || echo "000")
        if [ "$FED_CODE" = "200" ]; then
            success "  Federation port 8448 working"
        else
            warn "  Federation port 8448 returned $FED_CODE"
        fi

        # IPv6
        IPV6_CODE=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://matrix.${DOMAIN}/_matrix/client/versions" 2>/dev/null || echo "000")
        if [ "$IPV6_CODE" = "200" ]; then
            success "  IPv6 working"
        else
            info "  IPv6 not available (optional)"
        fi
    fi
    echo

    # ─── Security ───
    echo -e "  ${BOLD}Security:${NC}"

    # UFW
    if command -v ufw &>/dev/null && $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
        success "  UFW firewall active"
    else
        warn "  UFW firewall not active"
        issues+=("Firewall not active")
    fi

    # Fail2ban
    if systemctl is-active fail2ban &>/dev/null; then
        success "  Fail2ban active"
    else
        warn "  Fail2ban not active"
        issues+=("Fail2ban not running")
    fi

    # SSH config
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        success "  SSH password auth disabled"
    else
        warn "  SSH password auth may be enabled"
        issues+=("SSH password auth enabled")
    fi

    # Swap
    if swapon --show 2>/dev/null | grep -q "/"; then
        SWAP_SIZE=$(swapon --show --noheadings --bytes 2>/dev/null | awk '{sum+=$3}END{printf "%.0fMB", sum/1024/1024}')
        success "  Swap configured ($SWAP_SIZE)"
    else
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_RAM" -lt 2048 ]; then
            warn "  No swap (RAM: ${TOTAL_RAM}MB)"
            issues+=("No swap configured")
        else
            success "  No swap needed (${TOTAL_RAM}MB RAM)"
        fi
    fi

    # Auto updates
    if dpkg -l 2>/dev/null | grep -q unattended-upgrades; then
        success "  Auto security updates enabled"
    else
        warn "  Auto security updates not installed"
        issues+=("No auto updates")
    fi
    echo

    # ─── TLS ───
    echo -e "  ${BOLD}TLS Certificates:${NC}"
    if [ -f "$INSTALL_DIR/certs/turn.crt" ]; then
        CERT_EXPIRY=$(openssl x509 -in "$INSTALL_DIR/certs/turn.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
        CERT_EPOCH=$(date -d "$CERT_EXPIRY" +%s 2>/dev/null || echo 0)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (CERT_EPOCH - NOW_EPOCH) / 86400 ))
        
        if [ "$DAYS_LEFT" -gt 14 ]; then
            success "  Coturn TLS cert valid ($DAYS_LEFT days left)"
        elif [ "$DAYS_LEFT" -gt 0 ]; then
            warn "  Coturn TLS cert expires in $DAYS_LEFT days"
            issues+=("TLS cert expiring soon")
        else
            error "  Coturn TLS cert EXPIRED"
            issues+=("TLS cert expired")
        fi
    else
        warn "  Coturn TLS cert not found"
        issues+=("No TLS cert for Coturn")
    fi

    # Cert watcher
    if systemctl is-active turn-cert-sync.path &>/dev/null; then
        success "  TLS auto-sync watcher active"
    else
        warn "  TLS auto-sync watcher not active"
        issues+=("Cert auto-sync not running")
    fi
    echo

    # ─── Disk ───
    echo -e "  ${BOLD}Resources:${NC}"
    DISK_USED=$(df -h / | awk 'NR==2{print $3}')
    DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')
    DISK_PCT=$(df -h / | awk 'NR==2{print $5}')
    success "  Disk: ${DISK_USED} used / ${DISK_AVAIL} free ($DISK_PCT)"

    RAM_USED=$(free -h | awk '/^Mem:/{print $3}')
    RAM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
    success "  RAM: ${RAM_USED} / ${RAM_TOTAL}"

    # ─── Registration Status ───
    echo
    echo -e "  ${BOLD}Registration:${NC}"
    if grep -q 'ALLOW_REGISTRATION: "true"' "$COMPOSE_FILE" 2>/dev/null; then
        warn "  Registration is OPEN"
    else
        success "  Registration is CLOSED"
    fi

    # ─── Summary ───
    echo
    separator
    if $all_ok && [ ${#issues[@]} -eq 0 ]; then
        echo -e "\n  ${BOLD}${GREEN}✅ All checks passed! Server is healthy.${NC}\n"
    else
        echo -e "\n  ${BOLD}${YELLOW}⚠️  Issues found (${#issues[@]}):${NC}"
        for issue in "${issues[@]}"; do
            echo -e "     • $issue"
        done
        echo
    fi

    press_enter
}

# ═══════════════════════════════════════════════
#  MENU 4: REGISTRATION MANAGEMENT
# ═══════════════════════════════════════════════
menu_registration() {
    show_header

    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Conduit is not installed."
        press_enter
        return
    fi

    load_config

    # Check current status
    local reg_open=false
    if grep -q 'ALLOW_REGISTRATION: "true"' "$COMPOSE_FILE" 2>/dev/null; then
        reg_open=true
    fi

    step "👤 Registration Management"

    if $reg_open; then
        echo -e "  Current status: ${YELLOW}● OPEN${NC}"
    else
        echo -e "  Current status: ${GREEN}● CLOSED${NC}"
    fi

    echo
    echo -e "  ${CYAN}1${NC}) Open registration"
    echo -e "  ${CYAN}2${NC}) Close registration"
    echo -e "  ${CYAN}3${NC}) Create account (via API)"
    echo -e "  ${CYAN}4${NC}) Show registration token"
    echo -e "  ${CYAN}0${NC}) Back to main menu"
    echo
    ask "Choose [0-4]:"
    read -r choice

    case $choice in
        1)
            $SUDO sed -i 's/ALLOW_REGISTRATION: "false"/ALLOW_REGISTRATION: "true"/' "$COMPOSE_FILE"
            cd "$INSTALL_DIR" && $SUDO docker compose up -d conduit >/dev/null 2>&1
            success "Registration OPENED"
            echo
            echo -e "  ${BOLD}Registration Token:${NC}"
            echo -e "  ${YELLOW}${REGISTRATION_TOKEN}${NC}"
            echo
            echo -e "  ${DIM}Users can register at: https://app.element.io/#/register${NC}"
            echo -e "  ${DIM}Homeserver: ${DOMAIN}${NC}"
            press_enter
            ;;
        2)
            $SUDO sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$COMPOSE_FILE"
            cd "$INSTALL_DIR" && $SUDO docker compose up -d conduit >/dev/null 2>&1
            success "Registration CLOSED"
            press_enter
            ;;
        3)
            menu_create_account
            ;;
        4)
            echo
            echo -e "  ${BOLD}Registration Token:${NC}"
            echo -e "  ${YELLOW}${REGISTRATION_TOKEN}${NC}"
            echo
            echo -e "  ${BOLD}Register at:${NC}"
            echo -e "  ${GREEN}https://app.element.io/#/register${NC}"
            echo -e "  Homeserver: ${GREEN}${DOMAIN}${NC}"
            press_enter
            ;;
        *)
            return
            ;;
    esac
}

# ─── Create account via Conduit admin API ───
menu_create_account() {
    echo
    step "Create New Account"

    load_config
    
    # Temporarily open registration
    local was_closed=false
    if grep -q 'ALLOW_REGISTRATION: "false"' "$COMPOSE_FILE" 2>/dev/null; then
        was_closed=true
        $SUDO sed -i 's/ALLOW_REGISTRATION: "false"/ALLOW_REGISTRATION: "true"/' "$COMPOSE_FILE"
        cd "$INSTALL_DIR" && $SUDO docker compose up -d conduit >/dev/null 2>&1
        sleep 3
        info "Temporarily opened registration..."
    fi

    ask "Username (without @):"
    read -r NEW_USER
    [ -z "$NEW_USER" ] && { error "Username required"; press_enter; return; }

    ask "Password:"
    read -rs NEW_PASS
    echo
    [ -z "$NEW_PASS" ] && { error "Password required"; press_enter; return; }

    # Register via Matrix client API
    info "Creating account @${NEW_USER}:${DOMAIN}..."
    
    REGISTER_RESPONSE=$(curl -s -X POST "https://matrix.${DOMAIN}/_matrix/client/v3/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"${NEW_USER}\",
            \"password\": \"${NEW_PASS}\",
            \"auth\": {
                \"type\": \"m.login.registration_token\",
                \"token\": \"${REGISTRATION_TOKEN}\",
                \"session\": \"\"
            },
            \"initial_device_display_name\": \"Server Script\"
        }" 2>/dev/null)

    # Check if we need a session
    SESSION=$(echo "$REGISTER_RESPONSE" | grep -o '"session":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$SESSION" ]; then
        REGISTER_RESPONSE=$(curl -s -X POST "https://matrix.${DOMAIN}/_matrix/client/v3/register" \
            -H "Content-Type: application/json" \
            -d "{
                \"username\": \"${NEW_USER}\",
                \"password\": \"${NEW_PASS}\",
                \"auth\": {
                    \"type\": \"m.login.registration_token\",
                    \"token\": \"${REGISTRATION_TOKEN}\",
                    \"session\": \"${SESSION}\"
                },
                \"initial_device_display_name\": \"Server Script\"
            }" 2>/dev/null)
    fi

    if echo "$REGISTER_RESPONSE" | grep -q "user_id"; then
        USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)
        success "Account created: ${USER_ID}"
    else
        ERROR_MSG=$(echo "$REGISTER_RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
        error "Failed: ${ERROR_MSG:-Unknown error}"
        echo -e "  ${DIM}Response: ${REGISTER_RESPONSE}${NC}"
    fi

    # Re-close if was closed
    if $was_closed; then
        $SUDO sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$COMPOSE_FILE"
        cd "$INSTALL_DIR" && $SUDO docker compose up -d conduit >/dev/null 2>&1
        info "Registration closed again"
    fi

    press_enter
}

# ═══════════════════════════════════════════════
#  MENU 5: SERVICE MANAGEMENT
# ═══════════════════════════════════════════════
menu_services() {
    show_header

    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Conduit is not installed."
        press_enter
        return
    fi

    step "🔧 Service Management"

    echo -e "  ${CYAN}1${NC}) Start all services"
    echo -e "  ${CYAN}2${NC}) Stop all services"
    echo -e "  ${CYAN}3${NC}) Restart all services"
    echo -e "  ${CYAN}4${NC}) View logs (live)"
    echo -e "  ${CYAN}5${NC}) Update containers (pull latest)"
    echo -e "  ${CYAN}6${NC}) Show resource usage"
    echo -e "  ${CYAN}0${NC}) Back to main menu"
    echo
    ask "Choose [0-6]:"
    read -r choice

    cd "$INSTALL_DIR"

    case $choice in
        1)
            $SUDO docker compose up -d 2>&1
            success "Services started"
            press_enter
            ;;
        2)
            $SUDO docker compose down 2>&1
            success "Services stopped"
            press_enter
            ;;
        3)
            $SUDO docker compose restart 2>&1
            success "Services restarted"
            press_enter
            ;;
        4)
            info "Press Ctrl+C to exit logs"
            sleep 1
            $SUDO docker compose logs -f --tail 50
            ;;
        5)
            info "Pulling latest images..."
            $SUDO docker compose pull 2>&1
            $SUDO docker compose up -d 2>&1
            success "Containers updated"
            press_enter
            ;;
        6)
            $SUDO docker stats --no-stream
            press_enter
            ;;
        *)
            return
            ;;
    esac
}

# ═══════════════════════════════════════════════
#  MAIN MENU
# ═══════════════════════════════════════════════
main_menu() {
    while true; do
        show_header
        echo -e "  ${CYAN}1${NC}) ${BOLD}Prepare${NC}      — What you need before installing"
        echo -e "  ${CYAN}2${NC}) ${BOLD}Install${NC}      — Deploy Matrix server"
        echo -e "  ${CYAN}3${NC}) ${BOLD}Health Check${NC} — Verify services & security"
        echo -e "  ${CYAN}4${NC}) ${BOLD}Registration${NC} — Open/close/create accounts"
        echo -e "  ${CYAN}5${NC}) ${BOLD}Services${NC}     — Start/stop/restart/update/logs"
        echo -e "  ${CYAN}0${NC}) ${BOLD}Exit${NC}"
        echo
        ask "Choose [0-5]:"
        read -r choice

        case $choice in
            1) menu_prepare ;;
            2) menu_install ;;
            3) menu_healthcheck ;;
            4) menu_registration ;;
            5) menu_services ;;
            0|q|Q) echo -e "\n${DIM}Goodbye! 👋${NC}\n"; exit 0 ;;
            *) warn "Invalid option"; sleep 1 ;;
        esac
    done
}

# ─── Entry point ───
if [ "$EUID" -ne 0 ]; then
    # Not root — check if sudo is available
    if ! command -v sudo &>/dev/null; then
        echo -e "${RED}❌${NC} Please run as root or install sudo: ${BOLD}apt install sudo${NC}"
        exit 1
    fi
    if ! sudo -n true 2>/dev/null && ! sudo true; then
        echo -e "${RED}❌${NC} sudo access required. Run: ${BOLD}sudo bash install.sh${NC}"
        exit 1
    fi
    info "Running with sudo privileges"
fi

main_menu
