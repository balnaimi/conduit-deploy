#!/usr/bin/env bash
#
# ╔═══════════════════════════════════════════════════╗
# ║  Matrix Conduit Server — Interactive Manager      ║
# ║  Deploy and manage your own Matrix server         ║
# ╚═══════════════════════════════════════════════════╝
#
# Requirements: Fresh Debian 13 VPS with root or sudo access
# Usage: sudo bash conduit-deploy.sh  (or as root: bash conduit-deploy.sh)
#

set -eo pipefail

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
info()    { echo -e "${BLUE}[i]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC}  $1"; }
error()   { echo -e "${RED}[X]${NC} $1"; }
step()    { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }
ask()     { echo -en "${BOLD}$1${NC} "; }

separator() {
    echo -e "${DIM}───────────────────────────────────────────────${NC}"
}

# ─── Docker TTY Isolation ───
# Docker Compose v5+ writes progress directly to /dev/tty, bypassing all
# stdout/stderr redirects. This kills SSH PTY sessions. These wrappers
# fully isolate Docker commands from the terminal.

# Silent docker compose (no output) — for background operations
_compose_quiet() {
    local tmpscript="/tmp/.conduit-dq-$$.sh"
    echo '#!/bin/bash' > "$tmpscript"
    echo "cd \"$INSTALL_DIR\" && docker compose \"\$@\" >/dev/null 2>&1" >> "$tmpscript"
    chmod +x "$tmpscript"
    $SUDO setsid bash "$tmpscript" "$@" </dev/null >/dev/null 2>/dev/null
    local rc=$?
    rm -f "$tmpscript"
    return $rc
}

# Docker compose with visible output — for user-facing operations (install, update)
# Runs in detached script, streams output back via temp file
_compose_visible() {
    local tmpscript="/tmp/.conduit-dv-$$.sh"
    local tmplog="/tmp/.conduit-dv-$$.log"
    echo '#!/bin/bash' > "$tmpscript"
    echo "cd \"$INSTALL_DIR\" && docker compose \"\$@\" >\"$tmplog\" 2>&1; echo \"\$?\" >> \"$tmplog\"" >> "$tmpscript"
    chmod +x "$tmpscript"
    $SUDO setsid bash "$tmpscript" "$@" </dev/null >/dev/null 2>/dev/null &
    local pid=$!
    # Wait for completion (simple wait, no polling that could trigger set -e)
    wait $pid 2>/dev/null || true
    # Show output and get exit code
    if [ -f "$tmplog" ]; then
        local exit_code=$(tail -1 "$tmplog" 2>/dev/null || echo "1")
        head -n -1 "$tmplog" 2>/dev/null || true
        rm -f "$tmplog" "$tmpscript"
        return ${exit_code:-1}
    fi
    rm -f "$tmpscript" "$tmplog"
    return 1
}

# Docker pull with TTY isolation
_docker_pull() {
    local tmpscript="/tmp/.conduit-dp-$$.sh"
    echo '#!/bin/bash' > "$tmpscript"
    echo "docker pull \"\$@\" >/dev/null 2>&1" >> "$tmpscript"
    chmod +x "$tmpscript"
    $SUDO setsid bash "$tmpscript" "$@" </dev/null >/dev/null 2>/dev/null
    local rc=$?
    rm -f "$tmpscript"
    return $rc
}

# Get image name for a compose service (compatible with Docker Compose v2+v5)
# Usage: get_compose_image <service_name>
# Returns: repository:tag (e.g. "caddy:2-alpine")
get_compose_image() {
    local svc="$1"
    # Try JSON format first (works on Compose v2.21+ and v5+)
    local img=$($SUDO docker compose images "$svc" --format json 2>/dev/null | \
        python3 -c "import json,sys; data=json.load(sys.stdin); print(f\"{data[0]['Repository']}:{data[0]['Tag']}\")" 2>/dev/null)
    if [ -n "$img" ] && [ "$img" != ":" ]; then
        echo "$img"
        return
    fi
    # Fallback: parse table output
    img=$($SUDO docker compose images "$svc" 2>/dev/null | tail -n +2 | awk '{print $2":"$3}' | head -1)
    if [ -n "$img" ] && [ "$img" != ":" ]; then
        echo "$img"
        return
    fi
    echo ""
}

# Get all compose service images as "service repository:tag" lines
# Usage: get_all_compose_images (outputs one line per service)
get_all_compose_images() {
    # Try JSON format first
    local json=$($SUDO docker compose images --format json 2>/dev/null)
    if [ -n "$json" ]; then
        echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in data:
    svc = item.get('ContainerName', item.get('Service', ''))
    repo = item.get('Repository', '')
    tag = item.get('Tag', '')
    if repo and tag:
        print(f'{svc} {repo}:{tag}')
" 2>/dev/null && return
    fi
    # Fallback: parse table
    $SUDO docker compose images 2>/dev/null | tail -n +2 | awk '{print $1" "$2":"$3}'
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
        MATRIX_HOST="${MATRIX_HOST:-matrix.${DOMAIN}}"
        VPS_IP="${PUBLIC_IP:-}"
        # Only fetch IP from internet if not saved in .env
        if [ -z "$VPS_IP" ]; then
            VPS_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
        fi
    fi
}

# ─── Header ───
show_header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo '   ██████╗ ██████╗ ███╗   ██╗██████╗ ██╗   ██╗██╗████████╗'
    echo '  ██╔════╝██╔═══██╗████╗  ██║██╔══██╗██║   ██║██║╚══██╔══╝'
    echo '  ██║     ██║   ██║██╔██╗ ██║██║  ██║██║   ██║██║   ██║   '
    echo '  ██║     ██║   ██║██║╚██╗██║██║  ██║██║   ██║██║   ██║   '
    echo '  ╚██████╗╚██████╔╝██║ ╚████║██████╔╝╚██████╔╝██║   ██║   '
    echo '   ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝  ╚═════╝ ╚═╝   ╚═╝   '
    echo -e "${NC}"
    echo -e "          ${DIM}Matrix Homeserver Deploy Tool${NC}"
    echo
    
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE" 2>/dev/null || true
        echo -e "  ${DIM}Domain: ${GREEN}${SERVER_NAME:-not set}${NC}"
        
        # Quick status
        if command -v docker &>/dev/null && timeout 3 $SUDO docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' conduit 2>/dev/null | grep -q "running"; then
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
    step "* Pre-Installation Checklist"

    echo -e "  ${DIM}This will tell you exactly what to set up before installing.${NC}"
    echo

    # ─── Domain Mode ───
    echo -e "  ${BOLD}* How do you want your usernames to look?${NC}"
    echo
    echo -e "  ${CYAN}1${NC}) ${BOLD}Clean username (Delegation)${NC}"
    echo -e "     Username: ${GREEN}@user:example.com${NC}"
    echo -e "     Server:   ${GREEN}matrix.example.com${NC}"
    echo -e "     ${DIM}Requires .well-known delegation on root domain${NC}"
    echo
    echo -e "  ${CYAN}2${NC}) ${BOLD}Subdomain only (Simple)${NC}"
    echo -e "     Username: ${GREEN}@user:chat.example.com${NC}"
    echo -e "     Server:   ${GREEN}chat.example.com${NC}"
    echo -e "     ${DIM}No delegation needed — just one DNS record${NC}"
    echo
    echo -e "  ${DIM}┌──────────────────┬───────────────────────┬───────────────────────┐${NC}"
    echo -e "  ${DIM}│                  │ Mode 1 (Delegation)   │ Mode 2 (Subdomain)    │${NC}"
    echo -e "  ${DIM}├──────────────────┼───────────────────────┼───────────────────────┤${NC}"
    echo -e "  ${DIM}│ Username         │ @user:example.com     │ @user:chat.example.com│${NC}"
    echo -e "  ${DIM}│ DNS records      │ 2-3 records           │ 1 record              │${NC}"
    echo -e "  ${DIM}│ Root domain      │ Must serve .well-known│ Not involved           │${NC}"
    echo -e "  ${DIM}│ Best for         │ Professional/permanent│ Quick setup/testing    │${NC}"
    echo -e "  ${DIM}└──────────────────┴───────────────────────┴───────────────────────┘${NC}"
    echo
    echo -e "  ${YELLOW}[!]  Your server name is PERMANENT — you cannot change it later!${NC}"
    echo
    ask "Choose [1/2]:"
    read -r PREP_MODE
    PREP_MODE=${PREP_MODE:-1}
    if [[ "$PREP_MODE" != "1" && "$PREP_MODE" != "2" ]]; then
        error "Invalid choice: $PREP_MODE (expected 1 or 2)"
        press_enter
        return
    fi
    echo

    echo -e "  ${DIM}Enter just the root domain (e.g. example.com), not the full server address${NC}"
    ask "Your domain name (e.g. example.com):"
    read -r PREP_DOMAIN
    if [ -z "$PREP_DOMAIN" ]; then
        error "Domain is required"
        press_enter
        return
    fi

    if [[ "$PREP_MODE" == "2" ]]; then
        ask "Subdomain for the server (e.g. chat, matrix, msg):"
        read -r PREP_SUB
        PREP_SUB=${PREP_SUB:-chat}
        # Warn if subdomain is already part of the domain
        if [[ "$PREP_DOMAIN" == "${PREP_SUB}."* ]]; then
            warn "It looks like '${PREP_DOMAIN}' already starts with '${PREP_SUB}'"
            echo -e "  ${DIM}The domain field should be just the root (e.g. example.com)${NC}"
            echo -e "  ${DIM}Result would be: ${PREP_SUB}.${PREP_DOMAIN} — is this correct?${NC}"
            ask "Continue anyway? [y/N]:"
            read -r confirm_domain
            if [[ ! "$confirm_domain" =~ ^[Yy]$ ]]; then
                info "Let's try again"
                press_enter
                return
            fi
        fi
        PREP_FULL="${PREP_SUB}.${PREP_DOMAIN}"
    fi

    # Detect IP
    PREP_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || \
              curl -s -4 --connect-timeout 5 api.ipify.org 2>/dev/null || \
              curl -s -4 --connect-timeout 5 icanhazip.com 2>/dev/null || echo "YOUR_VPS_IP")

    # Detect IPv6
    PREP_IPV6=$(ip -6 addr show scope global 2>/dev/null | awk '/inet6/{print $2}' | cut -d/ -f1 | head -1)

    echo
    separator
    echo -e "\n${BOLD}${GREEN}Before you install, complete these steps:${NC}\n"

    # ─── VPS Requirements ───
    echo -e "  ${BOLD}*  VPS Requirements:${NC}"
    echo -e "     • Debian 13 (or Ubuntu 22.04+)"
    echo -e "     • Minimum 512MB RAM (1GB+ recommended)"
    echo -e "     • 10GB+ free disk"
    echo -e "     • SSH access with root or sudo privileges"
    echo -e "     • Ports 80, 443, 8448, 3478, 5349 NOT blocked by provider"
    echo

    # ─── DNS Records ───
    echo -e "  ${BOLD}* DNS Records (add these in your DNS provider):${NC}"
    echo

    if [[ "$PREP_MODE" == "2" ]]; then
        # ── Subdomain mode ──
        echo -e "     ${CYAN}1.${NC} ${BOLD}A Record${NC} — Points to your server"
        echo -e "        Name:  ${GREEN}${PREP_SUB}${NC}"
        echo -e "        Value: ${GREEN}${PREP_IP}${NC}"
        echo -e "        Proxy: ${RED}OFF (DNS Only)${NC}"
        echo

        echo -e "     ${CYAN}2.${NC} ${BOLD}SRV Record${NC} — Federation discovery"
        echo -e "        Name:     ${GREEN}_matrix._tcp.${PREP_SUB}${NC}"
        echo -e "        Target:   ${GREEN}${PREP_FULL}${NC}"
        echo -e "        Port:     ${GREEN}443${NC}"
        echo -e "        Priority: 0  Weight: 1"
        echo

        if [ -n "$PREP_IPV6" ]; then
            echo -e "     ${CYAN}3.${NC} ${BOLD}AAAA Record${NC} — IPv6 (detected on this server)"
            echo -e "        Name:  ${GREEN}${PREP_SUB}${NC}"
            echo -e "        Value: ${GREEN}${PREP_IPV6}${NC}"
            echo -e "        Proxy: ${RED}OFF (DNS Only)${NC}"
            echo
        fi

        echo -e "  ${DIM}That's it! No .well-known needed for subdomain mode.${NC}"

    else
        # ── Delegation mode ──
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
        echo -e "  ${BOLD}* .well-known Delegation:${NC}"
        echo
        echo -e "     Your usernames will be ${GREEN}@user:${PREP_DOMAIN}${NC} but the server"
        echo -e "     runs at ${GREEN}matrix.${PREP_DOMAIN}${NC}. To link them:"
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
    fi

    echo
    separator
    echo
    echo -e "  ${BOLD}Your server identity:${NC}"
    if [[ "$PREP_MODE" == "2" ]]; then
        echo -e "     Server name: ${GREEN}${PREP_FULL}${NC}"
        echo -e "     Usernames:   ${GREEN}@user:${PREP_FULL}${NC}"
        echo -e "     Server URL:  ${GREEN}https://${PREP_FULL}${NC}"
    else
        echo -e "     Server name: ${GREEN}${PREP_DOMAIN}${NC}"
        echo -e "     Usernames:   ${GREEN}@user:${PREP_DOMAIN}${NC}"
        echo -e "     Server URL:  ${GREEN}https://matrix.${PREP_DOMAIN}${NC}"
    fi
    echo
    echo -e "  ${BOLD}* Apps to download:${NC}"
    echo -e "     • ${GREEN}Element${NC} — iOS / Android / Web / Desktop (most popular)"
    echo -e "     • ${GREEN}SchildiChat${NC} — iOS / Android (nicer UI)"
    echo -e "     • ${GREEN}FluffyChat${NC} — iOS / Android (lightweight)"

    echo
    separator
    echo -e "\n  ${BOLD}${YELLOW}Complete the above steps, then come back and choose 'Install'.${NC}\n"

    press_enter
    # Save choices so Install can use them as defaults
    mkdir -p /tmp/conduit-prepare 2>/dev/null
    echo "$PREP_MODE" > /tmp/conduit-prepare/mode
    echo "$PREP_DOMAIN" > /tmp/conduit-prepare/domain
    [[ "$PREP_MODE" == "2" ]] && echo "$PREP_SUB" > /tmp/conduit-prepare/subdomain
    info "Your choices are saved — Install will use them as defaults."
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
        # Auto-backup before reinstall
        info "Creating backup before reinstall..."
        do_backup "pre-reinstall" || true
    fi

    # ─── Pre-flight ───
    step "Pre-flight Checks"

    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        error "Root or sudo access required: ${BOLD}sudo bash conduit-deploy.sh${NC}"
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

    # ─── Domain Mode ───
    echo -e "  ${BOLD}* How do you want your usernames to look?${NC}"
    echo
    echo -e "  ${CYAN}1${NC}) ${BOLD}Clean username${NC} — @user:${BOLD}example.com${NC} (server at matrix.example.com)"
    echo -e "  ${CYAN}2${NC}) ${BOLD}Subdomain only${NC} — @user:${BOLD}chat.example.com${NC} (simpler, no delegation)"
    echo
    echo -e "  ${YELLOW}[!]  This is permanent — you cannot change it later!${NC}"
    echo
    # Load defaults from Prepare step (if run previously)
    local SAVED_MODE="" SAVED_DOMAIN="" SAVED_SUB=""
    [ -f /tmp/conduit-prepare/mode ] && SAVED_MODE=$(cat /tmp/conduit-prepare/mode)
    [ -f /tmp/conduit-prepare/domain ] && SAVED_DOMAIN=$(cat /tmp/conduit-prepare/domain)
    [ -f /tmp/conduit-prepare/subdomain ] && SAVED_SUB=$(cat /tmp/conduit-prepare/subdomain)

    if [ -n "$SAVED_MODE" ]; then
        ask "Choose [1/2] (from Prepare: ${SAVED_MODE}):"
    else
        ask "Choose [1/2]:"
    fi
    read -r DOMAIN_MODE
    DOMAIN_MODE=${DOMAIN_MODE:-${SAVED_MODE:-1}}
    if [[ "$DOMAIN_MODE" != "1" && "$DOMAIN_MODE" != "2" ]]; then
        error "Invalid choice: $DOMAIN_MODE (expected 1 or 2)"
        press_enter
        return
    fi

    echo
    echo -e "  ${DIM}Enter just the root domain (e.g. example.com), not the full server address${NC}"
    if [ -n "$SAVED_DOMAIN" ]; then
        ask "Your domain name [${GREEN}${SAVED_DOMAIN}${NC}]:"
    else
        ask "Your domain name:"
    fi
    read -r DOMAIN
    DOMAIN=${DOMAIN:-$SAVED_DOMAIN}
    [ -z "$DOMAIN" ] && { error "Domain is required"; press_enter; return; }
    # Basic domain validation
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        error "Invalid domain format: $DOMAIN"
        echo -e "  ${DIM}Example: example.com, my-server.net${NC}"
        press_enter
        return
    fi

    # Set MATRIX_HOST and SERVER_NAME based on mode
    if [[ "$DOMAIN_MODE" == "2" ]]; then
        if [ -n "$SAVED_SUB" ]; then
            ask "Subdomain for the server [${GREEN}${SAVED_SUB}${NC}]:"
        else
            ask "Subdomain for the server (e.g. chat, matrix, msg):"
        fi
        read -r SUBDOMAIN
        SUBDOMAIN=${SUBDOMAIN:-${SAVED_SUB:-chat}}
        # Warn if subdomain is already part of the domain
        if [[ "$DOMAIN" == "${SUBDOMAIN}."* ]]; then
            warn "It looks like '${DOMAIN}' already starts with '${SUBDOMAIN}'"
            echo -e "  ${DIM}The domain field should be just the root (e.g. example.com)${NC}"
            echo -e "  ${DIM}Result would be: ${SUBDOMAIN}.${DOMAIN}${NC}"
            ask "Continue anyway? [y/N]:"
            read -r confirm_domain
            if [[ ! "$confirm_domain" =~ ^[Yy]$ ]]; then
                info "Let's try again"
                press_enter
                return
            fi
        fi
        MATRIX_HOST="${SUBDOMAIN}.${DOMAIN}"
        SERVER_NAME="$MATRIX_HOST"    # username = @user:chat.example.com
        WELLKNOWN_MODE="NONE"
    else
        MATRIX_HOST="matrix.${DOMAIN}"
        SERVER_NAME="$DOMAIN"          # username = @user:example.com
    fi

    DETECTED_IP=$(curl -s -4 --connect-timeout 5 ifconfig.me 2>/dev/null || \
                  curl -s -4 --connect-timeout 5 api.ipify.org 2>/dev/null || \
                  curl -s -4 --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")
    if [ -n "$DETECTED_IP" ]; then
        ask "VPS public IP [${GREEN}${DETECTED_IP}${NC}]:"
        read -r VPS_IP
        VPS_IP=${VPS_IP:-$DETECTED_IP}
    else
        ask "VPS public IP:"
        read -r VPS_IP
    fi
    [ -z "$VPS_IP" ] && { error "VPS IP is required"; press_enter; return; }
    if [[ ! "$VPS_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid IP address format: $VPS_IP"
        press_enter
        return
    fi

    # Well-known delegation (only for Mode 1)
    if [[ "$DOMAIN_MODE" != "2" ]]; then
        echo
        echo -e "  ${BOLD}* .well-known Delegation${NC}"
        echo -e "  ${DIM}Your usernames will be @user:${DOMAIN} but the server runs at ${MATRIX_HOST}${NC}"
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
            echo -e "      return 200 '{\"m.server\": \"${MATRIX_HOST}:443\"}';"
            echo -e "      add_header Content-Type application/json;"
            echo -e "  }"
            echo -e "  location /.well-known/matrix/client {"
            echo -e "      return 200 '{\"m.homeserver\": {\"base_url\": \"https://${MATRIX_HOST}\"}}';"
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
    fi

    # ─── Media Settings ───
    echo
    separator
    echo -e "\n  ${BOLD}Media Settings${NC}\n"

    # Detect available disk and suggest smart defaults
    AVAIL_DISK_GB=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
    echo -e "  ${DIM}Available disk space: ${BOLD}${AVAIL_DISK_GB}GB${NC}"
    echo

    # Smart defaults based on disk size
    if [ "$AVAIL_DISK_GB" -ge 100 ]; then
        DEFAULT_MEDIA_GB=50
        DEFAULT_THUMB_GB=5
    elif [ "$AVAIL_DISK_GB" -ge 50 ]; then
        DEFAULT_MEDIA_GB=20
        DEFAULT_THUMB_GB=2
    elif [ "$AVAIL_DISK_GB" -ge 20 ]; then
        DEFAULT_MEDIA_GB=10
        DEFAULT_THUMB_GB=1
    else
        DEFAULT_MEDIA_GB=3
        DEFAULT_THUMB_GB=1
    fi

    echo -e "  ${DIM}Maximum file size a user can upload (images, videos, documents).${NC}"
    echo -e "  ${DIM}Matrix supports up to 1GB. Default: 100MB.${NC}"
    ask "Max upload size in MB [100]:"
    read -r MAX_UPLOAD_MB
    MAX_UPLOAD_MB=${MAX_UPLOAD_MB:-100}
    MAX_UPLOAD_BYTES=$((MAX_UPLOAD_MB * 1024 * 1024))

    echo
    echo -e "  ${DIM}Total disk space allowed for all media files.${NC}"
    echo -e "  ${DIM}When this limit is reached, oldest files are removed automatically.${NC}"
    ask "Max media storage in GB [${DEFAULT_MEDIA_GB}]:"
    read -r MEDIA_SPACE_GB
    MEDIA_SPACE_GB=${MEDIA_SPACE_GB:-$DEFAULT_MEDIA_GB}

    if [ "$MEDIA_SPACE_GB" -ge "$AVAIL_DISK_GB" ]; then
        warn "Media limit (${MEDIA_SPACE_GB}GB) is larger than available disk (${AVAIL_DISK_GB}GB)!"
        ask "Continue anyway? [y/N]:"
        read -r disk_confirm
        [[ "$disk_confirm" =~ ^[Yy]$ ]] || return
    fi

    echo
    echo -e "  ${BOLD}Media cleanup policy${NC}"
    echo
    echo -e "  ${DIM}There are two types of media on your server:${NC}"
    echo -e "  ${CYAN}Your users' files${NC}  — images, videos, documents they uploaded"
    echo -e "  ${CYAN}Cached files${NC}       — copies of files from other Matrix servers (federation)"
    echo
    echo -e "  ${DIM}Cached files can be re-downloaded anytime, so it's safe to clean them up.${NC}"
    echo -e "  ${DIM}Your users' files are the originals — be more careful with those.${NC}"
    echo

    echo -e "  ${DIM}Delete cached files if nobody opened them for X days [30]:${NC}"
    ask "Cached files idle expiry in days [30]:"
    read -r REMOTE_ACCESS_DAYS
    REMOTE_ACCESS_DAYS=${REMOTE_ACCESS_DAYS:-30}

    echo -e "  ${DIM}Delete cached files older than X days, even if still accessed [90]:${NC}"
    ask "Cached files max age in days [90]:"
    read -r REMOTE_CREATED_DAYS
    REMOTE_CREATED_DAYS=${REMOTE_CREATED_DAYS:-90}

    echo -e "  ${DIM}Delete your users' files if nobody opened them for X days [365]:${NC}"
    ask "User files idle expiry in days [365]:"
    read -r LOCAL_ACCESS_DAYS
    LOCAL_ACCESS_DAYS=${LOCAL_ACCESS_DAYS:-365}

    echo -e "  ${DIM}Max space for thumbnails (auto-generated previews) [${DEFAULT_THUMB_GB}GB]:${NC}"
    ask "Thumbnail storage in GB [${DEFAULT_THUMB_GB}]:"
    read -r THUMB_SPACE_GB
    THUMB_SPACE_GB=${THUMB_SPACE_GB:-$DEFAULT_THUMB_GB}

    REGISTRATION_TOKEN=$(openssl rand -hex 32)
    TURN_SECRET=$(openssl rand -hex 32)

    separator
    echo
    echo -e "  ${BOLD}Summary:${NC}"
    echo -e "  Server name: ${GREEN}${SERVER_NAME}${NC}"
    echo -e "  Usernames:   ${GREEN}@user:${SERVER_NAME}${NC}"
    echo -e "  Matrix URL:  ${GREEN}https://${MATRIX_HOST}${NC}"
    echo -e "  VPS IP:      ${GREEN}${VPS_IP}${NC}"
    echo -e "  Max upload:  ${GREEN}${MAX_UPLOAD_MB}MB${NC}"
    echo -e "  Media space: ${GREEN}${MEDIA_SPACE_GB}GB${NC} (thumbnails: ${THUMB_SPACE_GB}GB)"
    echo -e "  Cached files:${GREEN} delete after ${REMOTE_ACCESS_DAYS}d idle / ${REMOTE_CREATED_DAYS}d max${NC}"
    echo -e "  User files:  ${GREEN} delete after ${LOCAL_ACCESS_DAYS}d idle${NC}"
    if [[ "$WELLKNOWN_MODE" == "A" ]]; then
        echo -e "  .well-known: ${GREEN}Caddy (automatic)${NC}"
    elif [[ "$WELLKNOWN_MODE" == "B" ]]; then
        echo -e "  .well-known: ${YELLOW}External (your web server)${NC}"
    else
        echo -e "  .well-known: ${GREEN}Not needed (subdomain mode)${NC}"
    fi
    echo
    ask "Start installation? [Y/n]"
    read -r confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && return

    # ─── System Dependencies ───
    step "Checking Dependencies"

    # Map: command → package name (some differ)
    local -A dep_map=(
        [curl]=curl
        [openssl]=openssl
        [sed]=sed
        [grep]=grep
        [awk]=gawk
        [ss]=iproute2
        [dig]=dnsutils
        [tar]=tar
        [free]=procps
        [timedatectl]=systemd
    )

    local missing_pkgs=()
    local missing_cmds=()
    for cmd in "${!dep_map[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
            # Avoid duplicates in package list
            local pkg="${dep_map[$cmd]}"
            local already=false
            for p in "${missing_pkgs[@]}"; do
                [[ "$p" == "$pkg" ]] && already=true
            done
            $already || missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        info "Installing missing packages: ${missing_cmds[*]}"
        $SUDO apt-get update -qq >/dev/null 2>&1
        if ! $SUDO apt-get install -y -qq "${missing_pkgs[@]}" 2>/dev/null; then
            error "Failed to install: ${missing_pkgs[*]}"
            error "Run manually: sudo apt-get install ${missing_pkgs[*]}"
            press_enter
            return
        fi
        success "Dependencies installed (${missing_cmds[*]})"
    else
        success "All dependencies available"
    fi

    # ─── Port Check ───
    step "Checking Port Availability"
    local port_conflict=false
    for port in 80 443 8448; do
        local port_in_use=false
        local blocking="unknown"
        if command -v ss &>/dev/null; then
            if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
                port_in_use=true
                blocking=$(ss -tlnp 2>/dev/null | grep ":${port} " | grep -oP 'users:\(\("\K[^"]+' || echo "unknown")
            fi
        elif command -v netstat &>/dev/null; then
            if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
                port_in_use=true
                blocking=$(netstat -tlnp 2>/dev/null | grep ":${port} " | awk '{print $NF}' | cut -d/ -f2 || echo "unknown")
            fi
        fi
        if $port_in_use; then
            error "Port $port is already in use by: $blocking"
            port_conflict=true
        else
            success "Port $port is available"
        fi
    done
    if $port_conflict; then
        warn "Some ports are in use. Caddy needs ports 80, 443, and 8448 to be free."
        ask "Continue anyway? [y/N]:"
        read -r port_confirm
        [[ "$port_confirm" =~ ^[Yy]$ ]] || return
    fi

    # ─── DNS Check ───
    step "Verifying DNS"
    local dns_ok=true
    RESOLVED_IP=$(dig +short "$MATRIX_HOST" A 2>/dev/null | head -1)
    if [ -z "$RESOLVED_IP" ]; then
        # dig might not be installed, try host command
        RESOLVED_IP=$(host "$MATRIX_HOST" 2>/dev/null | awk '/has address/{print $NF}' | head -1)
    fi
    if [ -z "$RESOLVED_IP" ]; then
        # Last resort: getent
        RESOLVED_IP=$(getent hosts "$MATRIX_HOST" 2>/dev/null | awk '{print $1}' | head -1)
    fi

    if [ -z "$RESOLVED_IP" ]; then
        warn "$MATRIX_HOST does not resolve to any IP address."
        warn "Make sure you've added the DNS A record before continuing."
        warn "Without DNS, Let's Encrypt cannot issue a TLS certificate."
        echo
        ask "Continue anyway? (Let's Encrypt will retry) [y/N]:"
        read -r dns_confirm
        [[ "$dns_confirm" =~ ^[Yy]$ ]] || return
    elif [ "$RESOLVED_IP" != "$VPS_IP" ]; then
        warn "$MATRIX_HOST resolves to $RESOLVED_IP (expected $VPS_IP)"
        warn "DNS might not have propagated yet, or the A record points elsewhere."
        echo
        ask "Continue anyway? [y/N]:"
        read -r dns_confirm
        [[ "$dns_confirm" =~ ^[Yy]$ ]] || return
    else
        success "$MATRIX_HOST resolves to $VPS_IP"
    fi

    # ─── Timezone ───
    step "Timezone Configuration"
    CURRENT_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
    echo -e "  Current timezone: ${BOLD}${CURRENT_TZ}${NC}"
    echo
    ask "Change timezone? [y/N]"
    read -r tz_confirm
    if [[ "$tz_confirm" =~ ^[Yy]$ ]]; then
        $SUDO dpkg-reconfigure tzdata
        CURRENT_TZ=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
        success "Timezone set to: $CURRENT_TZ"
    else
        success "Keeping timezone: $CURRENT_TZ"
    fi

    # ─── Install Docker ───
    step "Installing Docker"
    if command -v docker &>/dev/null; then
        success "Docker already installed"
    else
        info "Installing Docker..."
        if ! curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
            error "Failed to download Docker installer. Check your internet connection."
            press_enter
            return
        fi
        if ! $SUDO sh /tmp/get-docker.sh; then
            error "Docker installation failed. Check the output above."
            rm -f /tmp/get-docker.sh
            press_enter
            return
        fi
        rm -f /tmp/get-docker.sh
        $SUDO systemctl enable --now docker
        success "Docker installed"
    fi
    $SUDO docker compose version &>/dev/null || { error "Docker Compose v2 not found"; press_enter; return; }
    success "Docker Compose available"

    # ─── Firewall ───
    step "Configuring Firewall"
    if ! command -v ufw &>/dev/null; then
        $SUDO apt-get install -y -qq ufw >/dev/null 2>&1
    fi
    # Only set defaults if UFW is not already active (don't reset existing rules)
    if ! $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
        $SUDO ufw default deny incoming >/dev/null 2>&1
        $SUDO ufw default allow outgoing >/dev/null 2>&1
    fi
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
        if [ -f /swapfile ]; then
            # Swapfile exists but not active — try to activate it
            $SUDO chmod 600 /swapfile
            $SUDO swapon /swapfile 2>/dev/null && success "Swap re-activated" || warn "Existing /swapfile found but could not activate"
        else
            if ! $SUDO fallocate -l 2G /swapfile 2>/dev/null; then
                $SUDO dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none 2>/dev/null
            fi
            $SUDO chmod 600 /swapfile
            $SUDO mkswap /swapfile >/dev/null 2>&1 && $SUDO swapon /swapfile
            success "Swap 2GB configured"
        fi
        grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" | $SUDO tee -a /etc/fstab > /dev/null
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
    # Clean up old kernels/deps but never auto-reboot
    $SUDO tee /etc/apt/apt.conf.d/50unattended-upgrades-local > /dev/null << 'APTEOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
APTEOF
    success "Auto security patches enabled (no auto-reboot — you decide when)"

    # ─── Config files ───
    step "Creating Configuration Files"
    $SUDO mkdir -p "$INSTALL_DIR/certs"
    cd "$INSTALL_DIR"

    # .env
    $SUDO tee .env > /dev/null << EOF
SERVER_NAME=${SERVER_NAME}
MATRIX_HOST=${MATRIX_HOST}
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
      CONDUIT_TURN_URIS: '["turn:${MATRIX_HOST}?transport=udp","turn:${MATRIX_HOST}?transport=tcp","stun:${MATRIX_HOST}"]'
      CONDUIT_TURN_SECRET: ${TURN_SECRET}
      CONDUIT_WELL_KNOWN_CLIENT: "https://${MATRIX_HOST}"
      CONDUIT_WELL_KNOWN_SERVER: "${MATRIX_HOST}:443"
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
        # Delegation + Caddy serves .well-known on root domain
        $SUDO tee Caddyfile > /dev/null << EOF
${MATRIX_HOST}:443 {
    reverse_proxy conduit:6167
}

${MATRIX_HOST}:8448 {
    reverse_proxy conduit:6167
}

${DOMAIN}:443 {
    header /.well-known/matrix/* Content-Type application/json
    header /.well-known/matrix/client Access-Control-Allow-Origin *

    respond /.well-known/matrix/server \`{"m.server": "${MATRIX_HOST}:443"}\` 200
    respond /.well-known/matrix/client \`{"m.homeserver": {"base_url": "https://${MATRIX_HOST}"}}\` 200

    respond "Not Found" 404
}
EOF
    elif [[ "$WELLKNOWN_MODE" == "B" ]]; then
        # Delegation + .well-known handled externally
        $SUDO tee Caddyfile > /dev/null << EOF
${MATRIX_HOST}:443 {
    reverse_proxy conduit:6167
}

${MATRIX_HOST}:8448 {
    reverse_proxy conduit:6167
}
EOF
    else
        # Subdomain-only mode — no delegation needed
        $SUDO tee Caddyfile > /dev/null << EOF
${MATRIX_HOST}:443 {
    reverse_proxy conduit:6167
}

${MATRIX_HOST}:8448 {
    reverse_proxy conduit:6167
}
EOF
    fi
    success "Created Caddyfile"

    # turnserver.conf
    local TURN_IPV6_LINE=""
    if ip -6 addr show scope global 2>/dev/null | grep -q "inet6"; then
        TURN_IPV6_LINE="listening-ip=::"
    fi
    $SUDO tee turnserver.conf > /dev/null << EOF
# Coturn TURN/STUN Configuration
listening-port=3478
tls-listening-port=5349

# TLS Certificates
cert=/etc/turn-certs/turn.crt
pkey=/etc/turn-certs/turn.key

# Listen on IPv4${TURN_IPV6_LINE:+ + IPv6}
listening-ip=0.0.0.0
${TURN_IPV6_LINE}

# Relay
min-port=49152
max-port=65535
relay-ip=${VPS_IP}
external-ip=${VPS_IP}

# Authentication (shared secret with Conduit)
use-auth-secret
static-auth-secret=${TURN_SECRET}
realm=${MATRIX_HOST}

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
    $SUDO tee conduit.toml > /dev/null << EOF
[global]

[global.media]
backend = "filesystem"

[[global.media.retention]]
space = "${MEDIA_SPACE_GB}GB"

[[global.media.retention]]
scope = "remote"
accessed = "${REMOTE_ACCESS_DAYS}d"
created = "${REMOTE_CREATED_DAYS}d"

[[global.media.retention]]
scope = "local"
accessed = "${LOCAL_ACCESS_DAYS}d"

[[global.media.retention]]
scope = "thumbnail"
space = "${THUMB_SPACE_GB}GB"
EOF
    success "Created conduit.toml"

    # ─── Start ───
    step "Starting Services"
    info "Pulling Docker images (this may take a minute)..."
    _compose_visible pull
    info "Starting containers..."
    if ! _compose_visible up -d; then
        error "Failed to start services. Check: sudo docker compose -f $COMPOSE_FILE logs"
        press_enter
        return
    fi
    
    info "Waiting for Let's Encrypt certificate (up to 60s)..."
    local https_ok=false
    for i in $(seq 1 12); do
        sleep 5
        local remaining=$(( (12 - i) * 5 ))
        if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://${MATRIX_HOST}/_matrix/client/versions" 2>/dev/null | grep -q "200"; then
            success "HTTPS is working!"
            https_ok=true
            break
        fi
        echo -ne "\r  ${DIM}Waiting... ${remaining}s remaining${NC}   "
    done
    echo
    if ! $https_ok; then
        warn "HTTPS not responding yet. This is normal if DNS hasn't propagated."
        echo -e "  ${DIM}Caddy will keep trying to get a certificate in the background.${NC}"
        echo -e "  ${DIM}Check later with: sudo docker logs caddy${NC}"
        echo -e "  ${DIM}Or run Health Check from the main menu.${NC}"
    fi

    # Copy TLS certs for Coturn — find volume dynamically
    local CADDY_VOLUME=$($SUDO docker volume inspect --format '{{.Mountpoint}}' "$($SUDO docker inspect caddy --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null)" 2>/dev/null)
    CERT_DIR="${CADDY_VOLUME:-/var/lib/docker/volumes/conduit_caddy-data/_data}/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${MATRIX_HOST}"
    if [ -d "$CERT_DIR" ]; then
        $SUDO cp "$CERT_DIR/${MATRIX_HOST}.crt" "$INSTALL_DIR/certs/turn.crt"
        $SUDO cp "$CERT_DIR/${MATRIX_HOST}.key" "$INSTALL_DIR/certs/turn.key"
        $SUDO chmod 644 "$INSTALL_DIR/certs/turn."*
        _compose_quiet restart coturn
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
PathChanged=${CERT_DIR}/${MATRIX_HOST}.crt

[Install]
WantedBy=multi-user.target
EOF

    $SUDO tee /etc/systemd/system/turn-cert-sync.service > /dev/null << EOF
[Unit]
Description=Sync TLS certs from Caddy to Coturn

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cp "${CERT_DIR}/${MATRIX_HOST}.crt" "${INSTALL_DIR}/certs/turn.crt"; cp "${CERT_DIR}/${MATRIX_HOST}.key" "${INSTALL_DIR}/certs/turn.key"; chmod 644 ${INSTALL_DIR}/certs/turn.*; docker restart coturn'
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
Matrix URL:         https://${MATRIX_HOST}
VPS IP:             ${VPS_IP}

Registration Token: ${REGISTRATION_TOKEN}
TURN Secret:        ${TURN_SECRET}

Install directory:  ${INSTALL_DIR}

[!]  DELETE THIS FILE after saving credentials!
═══════════════════════════════════════════
EOF
    $SUDO chmod 600 "$CREDS_FILE"

    # ─── Done ───
    step "Installation Complete! "
    echo -e "  ${GREEN}Your Matrix server is running at:${NC}"
    echo -e "  ${BOLD}https://${MATRIX_HOST}${NC}"
    echo
    echo -e "  ${BOLD}Registration Token:${NC}"
    echo -e "  ${YELLOW}${REGISTRATION_TOKEN}${NC}"
    echo
    echo -e "  ${DIM}Credentials saved to: ${CREDS_FILE}${NC}"
    echo -e "  ${DIM}Token also stored in: ${ENV_FILE} (always recoverable from menu)${NC}"
    echo
    warn "Registration is currently OPEN. Use the menu to close it after creating accounts."

    press_enter
}

# ═══════════════════════════════════════════════
#  MENU 3: HEALTH CHECK
# ═══════════════════════════════════════════════
menu_healthcheck() {
    show_header
    step "* Health Check"

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
        if timeout 5 $SUDO docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' "$svc" 2>/dev/null | grep -q "running"; then
            success "  $svc is running"
        else
            error "  $svc is NOT running (or Docker is slow)"
            all_ok=false
            issues+=("$svc is down")
        fi
    done
    echo

    # ─── HTTPS ───
    echo -e "  ${BOLD}Connectivity:${NC}"
    if [ -n "$DOMAIN" ]; then
        HTTP_CODE=$(curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" "https://${MATRIX_HOST}/_matrix/client/versions" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            success "  HTTPS working (${MATRIX_HOST})"
        else
            error "  HTTPS failed (HTTP $HTTP_CODE)"
            all_ok=false
            issues+=("HTTPS not working")
        fi

        FED_CODE=$(curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" "https://${MATRIX_HOST}:8448/_matrix/client/versions" 2>/dev/null || echo "000")
        if [ "$FED_CODE" = "200" ]; then
            success "  Federation port 8448 working"
        else
            warn "  Federation port 8448 returned $FED_CODE"
        fi

        # IPv6
        IPV6_CODE=$(curl -6 -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://${MATRIX_HOST}/_matrix/client/versions" 2>/dev/null || echo "000")
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

    # OS security patches
    if dpkg -l 2>/dev/null | grep -q unattended-upgrades; then
        success "  OS security patches enabled (no auto-reboot)"
    else
        warn "  OS security patches not installed"
        issues+=("No security patches")
    fi

    # Check if reboot is needed
    if [ -f /var/run/reboot-required ]; then
        warn "  System reboot required (kernel or critical update pending)"
        issues+=("Reboot required")
        echo -e "     ${DIM}Run 'sudo reboot' when you're ready — your services will restart automatically.${NC}"
    else
        success "  No reboot pending"
    fi

    # Check if services need restart
    if command -v needrestart &>/dev/null; then
        local needs_restart=$($SUDO needrestart -b 2>/dev/null | grep "NEEDRESTART-SVC" | wc -l)
        if [ "$needs_restart" -gt 0 ]; then
            warn "  $needs_restart service(s) need restart after updates"
            $SUDO needrestart -b 2>/dev/null | grep "NEEDRESTART-SVC" | while read line; do
                local svc=$(echo "$line" | awk '{print $2}')
                echo -e "     ${DIM}• $svc${NC}"
            done
            issues+=("Services need restart")
        fi
    elif [ -d /run/needrestart ] || [ -f /var/run/needrestart ]; then
        warn "  Some services may need restart after updates"
        issues+=("Services may need restart")
    fi
    echo

    # ─── TLS ───
    echo -e "  ${BOLD}TLS Certificates:${NC}"
    if [ -f "$INSTALL_DIR/certs/turn.crt" ]; then
        CERT_EXPIRY=$(openssl x509 -in "$INSTALL_DIR/certs/turn.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ -z "$CERT_EXPIRY" ]; then
            warn "  Coturn TLS cert — could not read expiry"
            issues+=("Could not check TLS cert")
        else
            CERT_EPOCH=$(date -d "$CERT_EXPIRY" +%s 2>/dev/null)
            if [ -z "$CERT_EPOCH" ]; then
                warn "  Coturn TLS cert — date parsing failed (check manually: openssl x509 -in ${INSTALL_DIR}/certs/turn.crt -noout -enddate)"
                issues+=("Could not parse TLS cert date")
            else
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
            fi
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
    DISK_PCT=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [ "$DISK_PCT" -ge 90 ]; then
        error "  Disk: ${DISK_USED} used / ${DISK_AVAIL} free (${DISK_PCT}%) — CRITICAL!"
        all_ok=false
        issues+=("Disk usage at ${DISK_PCT}%")
    elif [ "$DISK_PCT" -ge 80 ]; then
        warn "  Disk: ${DISK_USED} used / ${DISK_AVAIL} free (${DISK_PCT}%) — getting full"
        issues+=("Disk usage at ${DISK_PCT}%")
    else
        success "  Disk: ${DISK_USED} used / ${DISK_AVAIL} free (${DISK_PCT}%)"
    fi

    RAM_USED=$(free -h | awk '/^Mem:/{print $3}')
    RAM_TOTAL=$(free -h | awk '/^Mem:/{print $2}')
    success "  RAM: ${RAM_USED} / ${RAM_TOTAL}"

    # ─── Registration Status ───
    echo
    echo -e "  ${BOLD}Registration:${NC}"
    local reg_env=$($SUDO docker inspect conduit --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep "CONDUIT_ALLOW_REGISTRATION=" | head -1)
    if echo "$reg_env" | grep -qi "true"; then
        warn "  Registration is OPEN"
    else
        success "  Registration is CLOSED"
    fi

    # ─── Summary ───
    echo
    separator
    if $all_ok && [ ${#issues[@]} -eq 0 ]; then
        echo -e "\n  ${BOLD}${GREEN}[OK] All checks passed! Server is healthy.${NC}\n"
    else
        echo -e "\n  ${BOLD}${YELLOW}[!]  Issues found (${#issues[@]}):${NC}"
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
  while true; do
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

    step "* Registration Management"

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
            if ! grep -q 'ALLOW_REGISTRATION: "false"' "$COMPOSE_FILE" 2>/dev/null; then
                warn "Registration is already OPEN"
            else
                $SUDO sed -i 's/ALLOW_REGISTRATION: "false"/ALLOW_REGISTRATION: "true"/' "$COMPOSE_FILE"
                cd "$INSTALL_DIR" && _compose_quiet up -d conduit
                success "Registration OPENED"
            fi
            echo
            echo -e "  ${BOLD}Registration Token:${NC}"
            if [ -z "$REGISTRATION_TOKEN" ]; then
                error "Token not found in .env (corrupted?)"
                error "Run Health Check and investigate /opt/conduit/.env"
            else
                echo -e "  ${YELLOW}${REGISTRATION_TOKEN}${NC}"
                echo
                echo -e "  ${DIM}Users can register at: https://app.element.io/#/register${NC}"
                echo -e "  ${DIM}Homeserver: ${SERVER_NAME}${NC}"
            fi
            press_enter
            ;;
        2)
            if ! grep -q 'ALLOW_REGISTRATION: "true"' "$COMPOSE_FILE" 2>/dev/null; then
                warn "Registration is already CLOSED"
            else
                $SUDO sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$COMPOSE_FILE"
                cd "$INSTALL_DIR" && _compose_quiet up -d conduit
                success "Registration CLOSED"
            fi
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
  done
}

# Helper: re-close registration if interrupted
_reclose_registration() {
    echo
    warn "Interrupted — closing registration..."
    $SUDO sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$COMPOSE_FILE" 2>/dev/null
    cd "$INSTALL_DIR" && _compose_quiet up -d conduit
    info "Registration closed."
    trap - INT
}

# ─── Create account via Conduit admin API ───
menu_create_account() {
    echo
    step "Create New Account"

    load_config

    # ─── Collect input FIRST (before touching registration state) ───
    ask "Username (without @, lowercase letters/numbers/dots/hyphens):"
    read -r NEW_USER
    [ -z "$NEW_USER" ] && { error "Username required"; press_enter; return; }
    if [[ ! "$NEW_USER" =~ ^[a-z0-9._-]{1,64}$ ]]; then
        error "Invalid username: only lowercase a-z, 0-9, dots, hyphens, underscores (max 64 chars)"
        press_enter
        return
    fi

    ask "Password (min 8 characters):"
    # Hide password input (stty fallback for shells where read -s doesn't work)
    if read -rs NEW_PASS 2>/dev/null; then
        echo
    else
        stty -echo 2>/dev/null
        read -r NEW_PASS
        stty echo 2>/dev/null
        echo
    fi
    [ -z "$NEW_PASS" ] && { error "Password required"; press_enter; return; }
    if [ ${#NEW_PASS} -lt 8 ]; then
        error "Password must be at least 8 characters (got ${#NEW_PASS})"
        press_enter
        return
    fi

    # Escape special characters for JSON
    NEW_PASS_ESCAPED=$(echo "$NEW_PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
    NEW_USER_ESCAPED=$(echo "$NEW_USER" | sed 's/\\/\\\\/g; s/"/\\"/g')

    # Restore TTY state before docker operations (read -rs may have changed it)
    stty sane 2>/dev/null || true

    # ─── Now open registration (input already collected, minimal window) ───
    local was_closed=false
    if grep -q 'ALLOW_REGISTRATION: "false"' "$COMPOSE_FILE" 2>/dev/null; then
        was_closed=true
        trap '_reclose_registration' INT
        info "Temporarily opening registration..."
        $SUDO sed -i 's/ALLOW_REGISTRATION: "false"/ALLOW_REGISTRATION: "true"/' "$COMPOSE_FILE"
        cd "$INSTALL_DIR" && _compose_quiet up -d conduit
        # Wait for container to be ready (setsid forks, compose runs in background briefly)
        sleep 5
        echo -e "  ${DIM}Registration briefly open (token still required). Will close after account creation.${NC}"
    fi

    # Register via Matrix client API
    # Temporarily disable pipefail — grep returns 1 on no-match which kills the script
    info "Creating account @${NEW_USER}:${SERVER_NAME}..."
    
    set +o pipefail 2>/dev/null

    # Step 1: Get UIAA session (send register without auth to get session ID)
    REGISTER_RESPONSE=$(curl -s --connect-timeout 10 --max-time 30 -X POST "https://${MATRIX_HOST}/_matrix/client/v3/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"${NEW_USER_ESCAPED}\",
            \"password\": \"${NEW_PASS_ESCAPED}\"
        }" 2>/dev/null || true)

    SESSION=$(echo "$REGISTER_RESPONSE" | grep -o '"session":"[^"]*"' | cut -d'"' -f4 || true)
    
    if [ -n "$SESSION" ]; then
        # Step 2: Complete registration with token + session
        REGISTER_RESPONSE=$(curl -s --connect-timeout 10 --max-time 30 -X POST "https://${MATRIX_HOST}/_matrix/client/v3/register" \
            -H "Content-Type: application/json" \
            -d "{
                \"username\": \"${NEW_USER_ESCAPED}\",
                \"password\": \"${NEW_PASS_ESCAPED}\",
                \"auth\": {
                    \"type\": \"m.login.registration_token\",
                    \"token\": \"${REGISTRATION_TOKEN}\",
                    \"session\": \"${SESSION}\"
                },
                \"initial_device_display_name\": \"Server Script\"
            }" 2>/dev/null || true)
    fi

    # Re-enable pipefail
    set -o pipefail 2>/dev/null

    if echo "$REGISTER_RESPONSE" | grep -q "user_id" 2>/dev/null; then
        USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4 || true)
        success "Account created: ${USER_ID}"
    else
        ERROR_MSG=$(echo "$REGISTER_RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4 || true)
        error "Failed: ${ERROR_MSG:-Unknown error}"
        echo -e "  ${DIM}Response: ${REGISTER_RESPONSE}${NC}"
    fi

    # Re-close if was closed
    if $was_closed; then
        trap - INT
        $SUDO sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$COMPOSE_FILE"
        cd "$INSTALL_DIR" && _compose_quiet up -d conduit
        info "Registration closed again"
    fi

    press_enter
}

# ═══════════════════════════════════════════════
#  BACKUP (with image version pinning)
# ═══════════════════════════════════════════════
do_backup() {
    local reason="${1:-manual}"

    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Conduit is not installed. Nothing to backup."
        return 1
    fi

    load_config
    cd "$INSTALL_DIR"

    # ─── Check disk space before backup ───
    local install_size_kb=$($SUDO du -sk "$INSTALL_DIR" 2>/dev/null | awk '{print $1}')
    local install_size_mb=$((install_size_kb / 1024))
    local avail_kb=$(df -k "$INSTALL_DIR" | awk 'NR==2{print $4}')
    local avail_mb=$((avail_kb / 1024))

    # Compressed backup is roughly 60-80% of original, estimate conservatively
    local estimated_backup_mb=$((install_size_mb * 80 / 100))

    if [ "$estimated_backup_mb" -ge "$avail_mb" ]; then
        error "Not enough disk space for backup!"
        echo -e "  Estimated backup size: ${BOLD}~${estimated_backup_mb}MB${NC}"
        echo -e "  Available disk space:  ${BOLD}${avail_mb}MB${NC}"
        echo
        echo -e "  ${DIM}Free up space by removing old backups:${NC}"
        # List existing backups
        local old_backups=$(ls -lh /opt/conduit-backups/conduit-backup-*.tar.gz 2>/dev/null)
        if [ -n "$old_backups" ]; then
            echo -e "  ${DIM}${old_backups}${NC}"
        else
            echo -e "  ${DIM}No old backups found in /opt/conduit-backups/${NC}"
        fi
        echo
        ask "Continue anyway? (backup may fail) [y/N]:"
        read -r space_confirm
        [[ "$space_confirm" =~ ^[Yy]$ ]] || return 1
    else
        success "Disk space OK (need ~${estimated_backup_mb}MB, have ${avail_mb}MB free)"
    fi

    # ─── Clean old backups ───
    local backup_count=$(ls /opt/conduit-backups/conduit-backup-*.tar.gz 2>/dev/null | wc -l)
    if [ "$backup_count" -ge 3 ]; then
        echo
        warn "You have ${backup_count} old backups in /opt/conduit-backups/:"
        ls -lhS /opt/conduit-backups/conduit-backup-*.tar.gz 2>/dev/null | while read line; do
            echo -e "  ${DIM}${line}${NC}"
        done
        echo
        ask "Delete old backups? Keep only the latest 2. [y/N]:"
        read -r cleanup_confirm
        if [[ "$cleanup_confirm" =~ ^[Yy]$ ]]; then
            ls -t /opt/conduit-backups/conduit-backup-*.tar.gz 2>/dev/null | tail -n +3 | while read old_file; do
                local old_size=$(du -h "$old_file" | awk '{print $1}')
                rm -f "$old_file"
                success "Deleted: $(basename "$old_file") ($old_size)"
            done
        fi
    fi

    # Save current image versions (pinned digests)
    step "Saving current image versions"
    local versions_file="$INSTALL_DIR/.image-versions"
    $SUDO bash -c "echo '# Image versions at backup time: $(date)' > '$versions_file'"
    for svc in conduit caddy coturn; do
        local img=$(cd "$INSTALL_DIR" && get_compose_image "$svc")
        local digest=""
        if [ -n "$img" ]; then
            digest=$($SUDO docker image inspect "$img" --format '{{index .RepoDigests 0}}' 2>/dev/null || echo "")
        fi
        if [ -n "$digest" ]; then
            echo "${svc}=${digest}" | $SUDO tee -a "$versions_file" >/dev/null
            success "$svc: $img → ${digest##*@sha256:}" | head -c 80
            echo
        else
            warn "$svc: could not get digest for $img"
        fi
    done

    # Create backup archive
    $SUDO mkdir -p /opt/conduit-backups
    BACKUP_FILE="/opt/conduit-backups/conduit-backup-$(date +%F-%H%M%S).tar.gz"
    info "Creating backup at $BACKUP_FILE..."
    if ! $SUDO tar czf "$BACKUP_FILE" -C / "$(echo "$INSTALL_DIR" | sed 's|^/||')" 2>/dev/null; then
        error "Failed to create backup archive. Check permissions and disk space."
        return 1
    fi
    
    if [ ! -f "$BACKUP_FILE" ] || [ ! -s "$BACKUP_FILE" ]; then
        error "Backup file is empty or doesn't exist"
        return 1
    fi
    
    local backup_size=$(du -h "$BACKUP_FILE" 2>/dev/null | awk '{print $1}')
    success "Backup saved: $BACKUP_FILE ($backup_size)"
    echo
    info "This backup includes:"
    echo -e "  • Database, media, and configuration files"
    echo -e "  • Pinned image versions (for exact rollback)"
    echo -e "  • TLS certificates and secrets"
    echo
    echo -e "  ${DIM}Backups are stored separately from the installation:${NC}"
    echo -e "  ${DIM}  /opt/conduit/          = installation (database, config, media)${NC}"
    echo -e "  ${DIM}  /opt/conduit-backups/  = backups (safe even if you uninstall)${NC}"

    return 0
}

do_restore() {
    step "Restore from Backup"

    echo -e "  ${DIM}Enter the path to your backup file (.tar.gz)${NC}"
    echo -e "  ${DIM}Backups are stored in: /opt/conduit-backups/${NC}"
    echo
    # List available backups
    local available_backups=$(ls -lhS /opt/conduit-backups/conduit-backup-*.tar.gz 2>/dev/null)
    if [ -n "$available_backups" ]; then
        echo -e "  ${BOLD}Available backups:${NC}"
        echo "$available_backups" | while read line; do
            echo -e "  ${DIM}${line}${NC}"
        done
        echo
    fi
    ask "Backup file path:"
    read -r RESTORE_FILE

    if [ ! -f "$RESTORE_FILE" ]; then
        error "File not found: $RESTORE_FILE"
        return 1
    fi

    echo
    echo -e "  ${RED}${BOLD}WARNING: This will replace your current installation!${NC}"
    echo -e "  ${YELLOW}All current data, accounts, and messages will be overwritten.${NC}"
    echo -e "  ${DIM}Restoring from: $(basename "$RESTORE_FILE")${NC}"
    echo
    ask "Type 'RESTORE' to confirm:"
    read -r confirm
    if [ "$confirm" != "RESTORE" ]; then
        info "Cancelled."
        return
    fi

    # Stop current services if running
    if [ -f "$COMPOSE_FILE" ]; then
        info "Stopping current services..."
        cd "$INSTALL_DIR" && _compose_quiet down
    fi

    # Restore files
    info "Restoring from backup..."
    if [ -n "$INSTALL_DIR" ] && [ "$INSTALL_DIR" != "/" ]; then
        $SUDO rm -rf "$INSTALL_DIR"
    else
        error "Invalid install directory. Aborting."
        return 1
    fi
    if ! $SUDO tar xzf "$RESTORE_FILE" -C / 2>/dev/null; then
        error "Failed to extract backup. File may be corrupted."
        return 1
    fi
    success "Files restored"

    # Check for pinned image versions
    local versions_file="$INSTALL_DIR/.image-versions"
    if [ -f "$versions_file" ]; then
        step "Restoring pinned image versions"
        echo -e "  ${DIM}Pulling the exact same images that were running at backup time.${NC}"
        echo

        local pinned_count=0
        local pinned_ok=0
        # Read all entries first, then pull (avoids stdin conflicts with setsid)
        local -a pin_services=()
        local -a pin_digests=()
        while IFS='=' read -r svc digest; do
            [[ "$svc" =~ ^#.*$ || -z "$svc" ]] && continue
            pin_services+=("$svc")
            pin_digests+=("$digest")
        done < "$versions_file"
        
        pinned_count=${#pin_services[@]}
        
        # Docker CLI v5 writes progress directly to /dev/tty, bypassing redirects.
        # Run all pulls in a detached helper script to fully isolate from TTY.
        local pull_script="/tmp/.conduit-restore-pull-$$.sh"
        local pull_log="/tmp/.conduit-restore-pull-$$.log"
        
        cat > "$pull_script" << 'PULLEOF'
#!/bin/bash
LOG="$1"; shift
> "$LOG"
while [ $# -gt 0 ]; do
    svc="$1"; digest="$2"; expected="$3"; shift 3
    if docker pull "$digest" >/dev/null 2>&1; then
        [ -n "$expected" ] && docker tag "$digest" "$expected" 2>/dev/null
        echo "OK $svc" >> "$LOG"
    else
        echo "FAIL $svc" >> "$LOG"
    fi
done
echo "DONE" >> "$LOG"
PULLEOF
        chmod +x "$pull_script"
        
        # Build arguments: svc digest expected_img triplets
        local pull_args=()
        for i in "${!pin_services[@]}"; do
            local svc="${pin_services[$i]}"
            local digest="${pin_digests[$i]}"
            local expected_img=""
            case "$svc" in
                conduit) expected_img="matrixconduit/matrix-conduit:latest" ;;
                caddy)   expected_img="caddy:2-alpine" ;;
                coturn)  expected_img="coturn/coturn:alpine" ;;
            esac
            pull_args+=("$svc" "$digest" "$expected_img")
        done
        
        # Run detached from TTY
        $SUDO setsid bash "$pull_script" "$pull_log" "${pull_args[@]}" </dev/null >/dev/null 2>/dev/null &
        local pull_pid=$!
        
        # Wait and show progress (|| true prevents set -e from killing on grep no-match)
        echo -ne "  Pulling images"
        while true; do
            if grep -q "DONE" "$pull_log" 2>/dev/null; then
                break
            fi
            echo -n "."
            sleep 2
        done
        wait $pull_pid 2>/dev/null
        echo
        
        # Show results
        while IFS=' ' read -r status svc; do
            if [ "$status" = "OK" ]; then
                echo -e "  ${GREEN}[OK]${NC} $svc"
                pinned_ok=$((pinned_ok + 1))
            elif [ "$status" = "FAIL" ]; then
                echo -e "  ${YELLOW}[!]${NC} $svc — could not pull pinned version"
            fi
        done < <(grep -v "DONE" "$pull_log" 2>/dev/null || true)
        
        rm -f "$pull_script" "$pull_log"
        
        # If some pinned images failed, fall back to latest
        if [ "$pinned_ok" -lt "$pinned_count" ]; then
            warn "Some pinned images could not be pulled. Falling back to latest..."
            cd "$INSTALL_DIR" && _compose_quiet pull || true
        fi
    else
        warn "No pinned image versions found in backup. Will use latest images."
        info "Pulling latest images..."
        cd "$INSTALL_DIR" && _compose_quiet pull
    fi

    # Start services (use setsid to prevent Docker TTY output from killing SSH)
    info "Starting services..."
    cd "$INSTALL_DIR" && _compose_quiet up -d
    sleep 3
    # Verify services started
    local all_up=true
    for svc in conduit caddy coturn; do
        if ! $SUDO docker compose ps "$svc" --format '{{.State}}' 2>/dev/null | grep -q "running"; then
            all_up=false
        fi
    done
    if $all_up; then
        success "Restore complete! Services are running."
    else
        warn "Restore complete but some services may still be starting."
        info "Run Health Check to verify, or wait a moment and try again."
    fi

    echo
    info "Run Health Check to verify everything is working."

    return 0
}

# ═══════════════════════════════════════════════
#  CHECK FOR UPDATES
# ═══════════════════════════════════════════════
check_for_updates() {
    step "* Checking for container updates..."
    echo

    cd "$INSTALL_DIR"
    local has_updates=false
    local services=()

    # Get list of images from compose
    while IFS= read -r line; do
        local svc=$(echo "$line" | awk '{print $1}')
        local img=$(echo "$line" | awk '{print $2}')
        [ -z "$img" ] && continue

        # Get local image digest
        local local_digest=$($SUDO docker image inspect "$img" --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//')

        # Check remote digest WITHOUT pulling (using Docker Hub API)
        echo -ne "  Checking ${BOLD}${svc}${NC} (${img})... "
        local repo=$(echo "$img" | cut -d: -f1)
        local tag=$(echo "$img" | cut -d: -f2)
        # Handle official images (no slash = library/)
        [[ "$repo" != */* ]] && repo="library/$repo"
        local token=$(curl -s --connect-timeout 10 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull" 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$token" ]; then
            echo -e "${RED}[X] Could not reach Docker Hub (network issue?)${NC}"
            continue
        fi
        local remote_digest=$(curl -s --connect-timeout 10 -H "Authorization: Bearer $token" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/${repo}/manifests/${tag}" 2>/dev/null | grep -o '"digest":"sha256:[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -z "$remote_digest" ]; then
            echo -e "${YELLOW}[!] Could not check remote version${NC}"
        elif [ -z "$local_digest" ]; then
            echo -e "${CYAN}[NEW]  New image${NC}"
            has_updates=true
            services+=("$svc")
        elif [ "$local_digest" != "$remote_digest" ]; then
            echo -e "${YELLOW}[UP]  Update available!${NC}"
            has_updates=true
            services+=("$svc")
        else
            echo -e "${GREEN}[OK] Up to date${NC}"
        fi
    done < <(cd "$INSTALL_DIR" && get_all_compose_images)

    echo
    if $has_updates; then
        warn "Updates available for: ${services[*]}"
        echo
        ask "Apply updates now? (restart containers with new images) [y/N]:"
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            ask "Create backup before updating? (recommended) [Y/n]:"
            read -r pre_upd_bk
            if [[ ! "$pre_upd_bk" =~ ^[Nn]$ ]]; then
                do_backup "pre-update"
                echo
            fi
            info "Pulling new images..."
            if ! _compose_visible pull; then
                error "Failed to pull images. Update aborted."
                if [ -n "$BACKUP_FILE" ]; then
                    warn "A backup was created before update: $BACKUP_FILE"
                fi
                press_enter
                return
            fi
            info "Restarting containers..."
            if ! _compose_visible up -d; then
                error "Failed to restart containers after update!"
                warn "Backup available if you need to rollback: $BACKUP_FILE"
                press_enter
                return
            fi
            success "Containers updated and restarted!"
            
            # Verify services came back up
            sleep 3
            info "Verifying services..."
            local all_running=true
            for svc in conduit caddy coturn; do
                if timeout 3 $SUDO docker compose ps --format '{{.State}}' "$svc" 2>/dev/null | grep -q "running"; then
                    success "  $svc is running"
                else
                    error "  $svc is NOT running"
                    all_running=false
                fi
            done
            echo
            if $all_running; then
                success "All services verified and running!"
            else
                error "Some services failed after update. Run Health Check for details."
                if [ -n "$BACKUP_FILE" ]; then
                    warn "Use 'Restore from backup' to rollback if needed: $BACKUP_FILE"
                fi
            fi
        else
            info "Skipped. Run 'Update containers' when ready."
            echo -e "  ${DIM}(Go to Services menu → Update containers)${NC}"
        fi
    else
        success "All containers are up to date!"
    fi
}

# ═══════════════════════════════════════════════
#  MENU 5: SERVICE MANAGEMENT
# ═══════════════════════════════════════════════
menu_services() {
  while true; do
    show_header

    local is_installed=true
    if [ ! -f "$COMPOSE_FILE" ]; then
        is_installed=false
    fi

    if $is_installed; then
        load_config
    fi

    step "* Service Management"

    if $is_installed; then
        echo -e "  ${CYAN}1${NC}) Start all services"
        echo -e "  ${CYAN}2${NC}) Stop all services"
        echo -e "  ${CYAN}3${NC}) Restart all services"
        echo -e "  ${CYAN}4${NC}) View logs (live)"
        echo -e "  ${CYAN}5${NC}) Update containers (pull latest)"
        echo -e "  ${CYAN}6${NC}) * Check for updates"
        echo -e "  ${CYAN}7${NC}) Backup (with version pinning)"
    else
        echo -e "  ${DIM}  Conduit is not installed. Only restore is available.${NC}"
        echo
    fi
    echo -e "  ${CYAN}8${NC}) Restore from backup"
    if $is_installed; then
        echo -e "  ${CYAN}9${NC}) Show resource usage"
    fi
    echo -e "  ${CYAN}0${NC}) Back to main menu"
    echo
    ask "Choose [0-9]:"
    read -r choice

    # Block options that need installation
    if ! $is_installed && [[ "$choice" =~ ^[1-7]$ || "$choice" == "9" ]]; then
        error "Conduit is not installed. Choose Restore (8) or go back (0)."
        press_enter
        continue
    fi

    if $is_installed; then
        cd "$INSTALL_DIR"
    fi

    case $choice in
        1)
            info "Starting services..."
            _compose_visible up -d
            success "Services started"
            press_enter
            ;;
        2)
            info "Stopping services..."
            _compose_visible down
            success "Services stopped"
            press_enter
            ;;
        3)
            info "Restarting services..."
            _compose_visible restart
            success "Services restarted"
            press_enter
            ;;
        4)
            info "Press Ctrl+C to exit logs"
            sleep 1
            $SUDO docker compose logs -f --tail 50
            ;;
        5)
            echo
            ask "Create backup before updating? (recommended) [Y/n]:"
            read -r pre_update_backup
            local bk_file=""
            if [[ ! "$pre_update_backup" =~ ^[Nn]$ ]]; then
                do_backup "pre-update" || { error "Backup failed, aborting update"; press_enter; continue; }
                bk_file="$BACKUP_FILE"
                echo
            fi
            info "Pulling latest images..."
            if ! _compose_visible pull; then
                error "Failed to pull images. Update aborted."
                [ -n "$bk_file" ] && warn "Backup available: $bk_file"
                press_enter
                continue
            fi
            info "Restarting containers..."
            if ! _compose_visible up -d; then
                error "Failed to restart containers!"
                [ -n "$bk_file" ] && warn "Use 'Restore from backup' to rollback: $bk_file"
                press_enter
                continue
            fi
            success "Containers updated and restarted!"
            
            # Quick verification
            sleep 2
            local verify_ok=true
            for svc in conduit caddy coturn; do
                if ! timeout 3 $SUDO docker compose ps --format '{{.State}}' "$svc" 2>/dev/null | grep -q "running"; then
                    verify_ok=false
                    break
                fi
            done
            if $verify_ok; then
                success "All services verified and running!"
            else
                warn "Some services may not be running. Run Health Check for details."
                [ -n "$bk_file" ] && warn "Backup: $bk_file"
            fi
            press_enter
            ;;
        6)
            check_for_updates
            press_enter
            ;;
        7)
            do_backup "manual"
            press_enter
            ;;
        8)
            do_restore
            press_enter
            ;;
        9)
            $SUDO docker stats --no-stream
            press_enter
            ;;
        *)
            return
            ;;
    esac
  done
}

# ═══════════════════════════════════════════════
#  MENU 6: UNINSTALL
# ═══════════════════════════════════════════════
menu_uninstall() {
    show_header
    step "Uninstall Matrix Conduit"

    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Conduit is not installed. Nothing to remove."
        press_enter
        return
    fi

    load_config

    echo -e "  ${RED}${BOLD}WARNING: This will permanently remove:${NC}"
    echo -e "  • All Docker containers (Conduit, Caddy, Coturn)"
    echo -e "  • All Docker volumes (database, media, certificates)"
    echo -e "  • Configuration files at ${INSTALL_DIR}/"
    echo -e "  • Firewall rules added by the installer"
    echo -e "  • TLS cert auto-sync service"
    echo -e "  • iptables UDP redirect rule"
    echo
    echo -e "  ${YELLOW}Your accounts, messages, and media will be LOST.${NC}"
    echo
    ask "Type 'UNINSTALL' to confirm:"
    read -r confirm
    if [ "$confirm" != "UNINSTALL" ]; then
        info "Cancelled."
        press_enter
        return
    fi

    echo
    ask "Create a backup before removing? [Y/n]:"
    read -r backup_confirm
    if [[ ! "$backup_confirm" =~ ^[Nn]$ ]]; then
        do_backup "pre-uninstall"
    fi

    # Stop and remove containers + volumes
    info "Stopping and removing containers..."
    cd "$INSTALL_DIR"
    _compose_quiet down -v
    success "Containers and volumes removed"

    # Remove cert watcher
    if systemctl is-enabled turn-cert-sync.path &>/dev/null 2>&1; then
        $SUDO systemctl stop turn-cert-sync.path 2>/dev/null || true
        $SUDO systemctl disable turn-cert-sync.path 2>/dev/null || true
        $SUDO rm -f /etc/systemd/system/turn-cert-sync.path
        $SUDO rm -f /etc/systemd/system/turn-cert-sync.service
        $SUDO systemctl daemon-reload
        success "TLS cert auto-sync removed"
    fi

    # Remove iptables rule
    if $SUDO iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "udp dpt:443.*5349"; then
        $SUDO iptables -t nat -D PREROUTING -p udp --dport 443 -j REDIRECT --to-port 5349 2>/dev/null || true
        $SUDO netfilter-persistent save 2>/dev/null || true
        success "iptables UDP redirect removed"
    fi

    # Remove firewall rules (reset UFW to deny all, keep SSH)
    if command -v ufw &>/dev/null && $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
        $SUDO ufw delete allow 80/tcp 2>/dev/null || true
        $SUDO ufw delete allow 443/tcp 2>/dev/null || true
        $SUDO ufw delete allow 8448/tcp 2>/dev/null || true
        $SUDO ufw delete allow 3478 2>/dev/null || true
        $SUDO ufw delete allow 5349 2>/dev/null || true
        $SUDO ufw delete allow 49152:65535/udp 2>/dev/null || true
        success "Firewall rules removed (SSH kept)"
    fi

    # Remove install directory
    $SUDO rm -rf "$INSTALL_DIR"
    success "Removed $INSTALL_DIR"

    echo
    separator
    echo -e "\n  ${GREEN}${BOLD}Uninstall complete.${NC}"
    echo -e "  Docker, fail2ban, and UFW are still installed (shared system packages)."
    if [[ ! "$backup_confirm" =~ ^[Nn]$ ]] && [ -n "$BACKUP_FILE" ]; then
        echo -e "  Backup saved at: ${BOLD}$BACKUP_FILE${NC}"
    fi

    # Offer to delete backups for full cleanup
    if [ -d "/opt/conduit-backups" ] && ls /opt/conduit-backups/conduit-backup-*.tar.gz &>/dev/null; then
        local bk_count=$(ls /opt/conduit-backups/conduit-backup-*.tar.gz 2>/dev/null | wc -l)
        local bk_size=$(du -sh /opt/conduit-backups 2>/dev/null | awk '{print $1}')
        echo
        echo -e "  ${YELLOW}You still have ${bk_count} backup(s) in /opt/conduit-backups/ (${bk_size})${NC}"
        ask "Delete all backups too? (completely remove everything) [y/N]:"
        read -r del_backups
        if [[ "$del_backups" =~ ^[Yy]$ ]]; then
            $SUDO rm -rf /opt/conduit-backups
            success "Backups deleted. Server is completely clean."
        else
            echo -e "  Backups kept at: ${BOLD}/opt/conduit-backups/${NC}"
        fi
    fi
    echo

    press_enter
}

# ═══════════════════════════════════════════════
#  MAIN MENU
# ═══════════════════════════════════════════════
# ─── Safety: check for orphaned open registration on startup ───
_check_orphaned_registration() {
    if [ -f "$COMPOSE_FILE" ] && grep -q 'ALLOW_REGISTRATION: "true"' "$COMPOSE_FILE" 2>/dev/null; then
        echo
        warn "Registration is currently OPEN!"
        echo -e "  ${DIM}This may be left over from a previous interrupted session.${NC}"
        ask "Close registration now? [Y/n]:"
        read -r close_reg
        if [[ ! "$close_reg" =~ ^[Nn]$ ]]; then
            $SUDO sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$COMPOSE_FILE"
            cd "$INSTALL_DIR" && _compose_quiet up -d conduit
            success "Registration closed"
        fi
    fi
}

main_menu() {
    _check_orphaned_registration
    while true; do
        show_header
        echo -e "  ${CYAN}1${NC}) ${BOLD}Prepare${NC}      — What you need before installing"
        echo -e "  ${CYAN}2${NC}) ${BOLD}Install${NC}      — Deploy Matrix server"
        echo -e "  ${CYAN}3${NC}) ${BOLD}Health Check${NC} — Verify services & security"
        echo -e "  ${CYAN}4${NC}) ${BOLD}Registration${NC} — Open/close/create accounts"
        echo -e "  ${CYAN}5${NC}) ${BOLD}Services${NC}     — Start/stop/restart/update/logs"
        echo -e "  ${CYAN}6${NC}) ${BOLD}Uninstall${NC}    — Remove everything"
        echo -e "  ${CYAN}0${NC}) ${BOLD}Exit${NC}"
        echo
        ask "Choose [0-6]:"
        read -r choice

        case $choice in
            1) menu_prepare ;;
            2) menu_install ;;
            3) menu_healthcheck ;;
            4) menu_registration ;;
            5) menu_services ;;
            6) menu_uninstall ;;
            0|q|Q) echo -e "\n${DIM}Goodbye! ${NC}\n"; exit 0 ;;
            *) warn "Invalid option"; sleep 1 ;;
        esac
    done
}

# ─── Entry point ───
if [ "$EUID" -ne 0 ]; then
    # Not root — check if sudo is available
    if ! command -v sudo &>/dev/null; then
        echo -e "${RED}[X]${NC} Please run as root or install sudo: ${BOLD}apt install sudo${NC}"
        exit 1
    fi
    if ! sudo -n true 2>/dev/null && ! sudo true; then
        echo -e "${RED}[X]${NC} sudo access required. Run: ${BOLD}sudo bash conduit-deploy.sh${NC}"
        exit 1
    fi
    info "Running with sudo privileges"
fi

main_menu
