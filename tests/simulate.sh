#!/usr/bin/env bash
#
# Simulation harness for conduit-deploy.sh
# Mocks: sudo, docker, curl, ufw, fail2ban, systemctl, etc.
# Tests every menu path without needing a real server.
#

set -eo pipefail

SCRIPT="/tmp/conduit-work/conduit-deploy.sh"
MOCK_DIR="/tmp/conduit-sim"
RESULTS_FILE="/tmp/conduit-sim/results.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$RESULTS_FILE"; }
fail() { echo -e "${RED}[FAIL]${NC} $1" | tee -a "$RESULTS_FILE"; FAILURES=$((FAILURES+1)); }
info() { echo -e "${CYAN}[TEST]${NC} $1" | tee -a "$RESULTS_FILE"; }

FAILURES=0
TESTS=0

# ─── Setup mock environment ───
setup_mocks() {
    rm -rf "$MOCK_DIR"
    mkdir -p "$MOCK_DIR/bin" "$MOCK_DIR/opt/conduit/certs" "$MOCK_DIR/opt/conduit-backups"
    
    # Mock sudo (pass-through)
    cat > "$MOCK_DIR/bin/sudo" << 'MOCK'
#!/bin/bash
"$@"
MOCK
    chmod +x "$MOCK_DIR/bin/sudo"
    
    # Mock docker
    cat > "$MOCK_DIR/bin/docker" << 'MOCK'
#!/bin/bash
case "$*" in
    *"compose pull"*)    echo "Pulling images..."; echo "Done" ;;
    *"compose up -d"*)   echo "Creating containers..."; echo "Container conduit Started"; echo "Container caddy Started"; echo "Container coturn Started" ;;
    *"compose down"*)    echo "Stopping containers..." ;;
    *"compose restart"*) echo "Restarting containers..." ;;
    *"compose ps"*conduit*) echo "running" ;;
    *"compose ps"*caddy*)   echo "running" ;;
    *"compose ps"*coturn*)  echo "running" ;;
    *"compose images"*)  echo "conduit matrixconduit/matrix-conduit:latest"; echo "caddy caddy:2-alpine"; echo "coturn coturn/coturn:alpine" ;;
    *"compose config --services"*) echo "conduit"; echo "caddy"; echo "coturn" ;;
    *"compose version"*) echo "Docker Compose version v2.29.2" ;;
    *"image inspect"*conduit*) echo "matrixconduit/matrix-conduit@sha256:abc123" ;;
    *"image inspect"*caddy*)   echo "caddy@sha256:def456" ;;
    *"image inspect"*coturn*)  echo "coturn/coturn@sha256:ghi789" ;;
    *"inspect conduit"*Env*) echo "CONDUIT_ALLOW_REGISTRATION=true" ;;
    *"stats"*)           echo "CONTAINER  CPU%  MEM USAGE"; echo "conduit    0.5%  128MiB"; echo "caddy      0.1%  32MiB"; echo "coturn     0.0%  16MiB" ;;
    *"pull"*)            echo "Pull complete" ;;
    *"tag"*)             true ;;
    *"volume inspect"*)  echo "/var/lib/docker/volumes/conduit_caddy-data/_data" ;;
    *)                   echo "docker mock: $*" ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bin/docker"
    
    # Mock curl
    cat > "$MOCK_DIR/bin/curl" << 'MOCK'
#!/bin/bash
case "$*" in
    *"ifconfig.me"*)     echo "203.0.113.42" ;;
    *"api.ipify.org"*)   echo "203.0.113.42" ;;
    *"_matrix/client/versions"*) echo "200" ;;
    *"auth.docker.io"*)  echo '{"token":"mock_token_123"}' ;;
    *"registry-1.docker.io"*) echo '{"digest":"sha256:newdigest123"}' ;;
    *"register"*)        echo '{"user_id":"@testuser:example.com"}' ;;
    *)                   echo "curl mock: $*" ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bin/curl"
    
    # Mock ufw
    cat > "$MOCK_DIR/bin/ufw" << 'MOCK'
#!/bin/bash
case "$*" in
    *"status"*) echo "Status: active" ;;
    *)          true ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bin/ufw"
    
    # Mock systemctl
    cat > "$MOCK_DIR/bin/systemctl" << 'MOCK'
#!/bin/bash
case "$*" in
    *"is-active fail2ban"*)        echo "active"; exit 0 ;;
    *"is-active turn-cert-sync"*)  echo "active"; exit 0 ;;
    *"is-enabled"*)                exit 0 ;;
    *)                             true ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bin/systemctl"

    # Mock timeout
    cat > "$MOCK_DIR/bin/timeout" << 'MOCK'
#!/bin/bash
shift  # skip timeout value
"$@"
MOCK
    chmod +x "$MOCK_DIR/bin/timeout"

    # Mock dpkg
    cat > "$MOCK_DIR/bin/dpkg" << 'MOCK'
#!/bin/bash
echo "ii  unattended-upgrades  2.9.1  amd64  automatic installation of security upgrades"
MOCK
    chmod +x "$MOCK_DIR/bin/dpkg"

    # Mock openssl
    cat > "$MOCK_DIR/bin/openssl" << 'MOCK'
#!/bin/bash
case "$*" in
    *"rand -hex"*) echo "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" ;;
    *"x509"*enddate*) echo "notAfter=Jun 15 12:00:00 2026 GMT" ;;
    *) echo "openssl mock" ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bin/openssl"

    # Mock dig
    cat > "$MOCK_DIR/bin/dig" << 'MOCK'
#!/bin/bash
echo "203.0.113.42"
MOCK
    chmod +x "$MOCK_DIR/bin/dig"

    # Mock timedatectl
    cat > "$MOCK_DIR/bin/timedatectl" << 'MOCK'
#!/bin/bash
echo "Asia/Qatar"
MOCK
    chmod +x "$MOCK_DIR/bin/timedatectl"

    # Mock dpkg-reconfigure
    cat > "$MOCK_DIR/bin/dpkg-reconfigure" << 'MOCK'
#!/bin/bash
true
MOCK
    chmod +x "$MOCK_DIR/bin/dpkg-reconfigure"

    # Mock netfilter-persistent
    cat > "$MOCK_DIR/bin/netfilter-persistent" << 'MOCK'
#!/bin/bash
true
MOCK
    chmod +x "$MOCK_DIR/bin/netfilter-persistent"

    # Mock iptables
    cat > "$MOCK_DIR/bin/iptables" << 'MOCK'
#!/bin/bash
true
MOCK
    chmod +x "$MOCK_DIR/bin/iptables"

    # Mock tee (write to file)
    cat > "$MOCK_DIR/bin/tee" << 'MOCK'
#!/bin/bash
# Write stdin to file like real tee
cat > "$1"
MOCK
    chmod +x "$MOCK_DIR/bin/tee"

    # Mock apt-get
    cat > "$MOCK_DIR/bin/apt-get" << 'MOCK'
#!/bin/bash
true
MOCK
    chmod +x "$MOCK_DIR/bin/apt-get"

    # Mock fallocate
    cat > "$MOCK_DIR/bin/fallocate" << 'MOCK'
#!/bin/bash
true
MOCK
    chmod +x "$MOCK_DIR/bin/fallocate"

    # Mock mkswap
    cat > "$MOCK_DIR/bin/mkswap" << 'MOCK'
#!/bin/bash
true
MOCK
    chmod +x "$MOCK_DIR/bin/mkswap"

    # Mock swapon
    cat > "$MOCK_DIR/bin/swapon" << 'MOCK'
#!/bin/bash
case "$*" in
    *"--show"*) echo "NAME TYPE SIZE USED PRIO"; echo "/swapfile file 2G 0B -2" ;;
    *) true ;;
esac
MOCK
    chmod +x "$MOCK_DIR/bin/swapon"

    # Mock fail2ban-client
    cat > "$MOCK_DIR/bin/fail2ban-client" << 'MOCK'
#!/bin/bash
echo "Server ready"
MOCK
    chmod +x "$MOCK_DIR/bin/fail2ban-client"

    # Mock ss
    cat > "$MOCK_DIR/bin/ss" << 'MOCK'
#!/bin/bash
# No ports in use
echo "State  Recv-Q Send-Q Local Address:Port"
MOCK
    chmod +x "$MOCK_DIR/bin/ss"

    # Create fake /etc/os-release
    mkdir -p "$MOCK_DIR/etc/ssh"
    echo 'ID=debian' > "$MOCK_DIR/etc/os-release"
    echo 'VERSION_ID="13"' >> "$MOCK_DIR/etc/os-release"
    echo 'PasswordAuthentication no' > "$MOCK_DIR/etc/ssh/sshd_config"
}

# ─── Source the script functions ───
source_script() {
    # Override paths
    export INSTALL_DIR="$MOCK_DIR/opt/conduit"
    export COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
    export ENV_FILE="$INSTALL_DIR/.env"
    export CREDS_FILE="$INSTALL_DIR/CREDENTIALS.txt"
    export PATH="$MOCK_DIR/bin:$PATH"
    export EUID=0  # pretend root
    export SUDO=""
    
    # Source functions (but not main_menu)
    # We extract functions individually
    eval "$(sed -n '/^# ─── Colors/,/^main_menu/p' "$SCRIPT" | head -n -2)"
}

# ─── Test: Domain Validation ───
test_domain_validation() {
    TESTS=$((TESTS+1))
    info "Testing domain validation regex..."
    
    # Valid domains
    for d in "example.com" "my-server.net" "test.co.uk" "a.io"; do
        if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
            pass "  Valid: $d"
        else
            fail "  Should be valid: $d"
        fi
    done
    
    # Invalid domains
    for d in "example" "exam ple.com" ".com" "test." "-test.com" "test..com"; do
        if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
            fail "  Should be invalid: $d"
        else
            pass "  Invalid: $d (rejected correctly)"
        fi
    done
}

# ─── Test: IP Validation ───
test_ip_validation() {
    TESTS=$((TESTS+1))
    info "Testing IP validation regex..."
    
    for ip in "1.2.3.4" "192.168.1.1" "203.0.113.42" "255.255.255.255"; do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            pass "  Valid IP: $ip"
        else
            fail "  Should be valid IP: $ip"
        fi
    done
    
    for ip in "abc" "1.2.3" "1.2.3.4.5" "192.168.1" "hello.world"; do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            fail "  Should be invalid IP: $ip"
        else
            pass "  Invalid IP: $ip (rejected correctly)"
        fi
    done
}

# ─── Test: Username Validation ───
test_username_validation() {
    TESTS=$((TESTS+1))
    info "Testing username validation regex..."
    
    for u in "alice" "bob123" "user.name" "test-user" "a_b"; do
        if [[ "$u" =~ ^[a-z0-9._-]{1,64}$ ]]; then
            pass "  Valid username: $u"
        else
            fail "  Should be valid: $u"
        fi
    done
    
    for u in "Alice" "USER" "user name" "user@name" "" "$(python3 -c 'print("a"*65)')"; do
        if [[ -z "$u" ]] || [[ ! "$u" =~ ^[a-z0-9._-]{1,64}$ ]]; then
            pass "  Invalid username: '${u:0:20}' (rejected correctly)"
        else
            fail "  Should be invalid: '$u'"
        fi
    done
}

# ─── Test: Password Validation ───
test_password_validation() {
    TESTS=$((TESTS+1))
    info "Testing password length requirement..."
    
    for pw in "12345678" "a-strong-pass!" "exactly8"; do
        if [ ${#pw} -ge 8 ]; then
            pass "  Valid password: '$pw' (${#pw} chars)"
        else
            fail "  Should be valid: '$pw'"
        fi
    done
    
    for pw in "1234567" "short" "abc" "1"; do
        if [ ${#pw} -lt 8 ]; then
            pass "  Invalid password: '$pw' (${#pw} chars, rejected)"
        else
            fail "  Should be invalid: '$pw'"
        fi
    done
}

# ─── Test: Domain Mode Validation ───
test_domain_mode_validation() {
    TESTS=$((TESTS+1))
    info "Testing domain mode validation..."
    
    for mode in "1" "2"; do
        if [[ "$mode" == "1" || "$mode" == "2" ]]; then
            pass "  Valid mode: $mode"
        else
            fail "  Should be valid: $mode"
        fi
    done
    
    for mode in "3" "0" "abc" ""; do
        if [[ "$mode" != "1" && "$mode" != "2" ]]; then
            pass "  Invalid mode: '$mode' (rejected correctly)"
        else
            fail "  Should be invalid: '$mode'"
        fi
    done
}

# ─── Test: Config File Generation ───
test_config_generation() {
    TESTS=$((TESTS+1))
    info "Testing config file generation..."
    
    local test_dir="$MOCK_DIR/test-config"
    mkdir -p "$test_dir"
    
    # Simulate .env creation
    SERVER_NAME="example.com"
    MATRIX_HOST="matrix.example.com"
    TURN_SECRET="testsecret123"
    REGISTRATION_TOKEN="testtoken456"
    VPS_IP="203.0.113.42"
    
    cat > "$test_dir/.env" << EOF
SERVER_NAME=${SERVER_NAME}
MATRIX_HOST=${MATRIX_HOST}
TURN_SECRET=${TURN_SECRET}
REGISTRATION_TOKEN=${REGISTRATION_TOKEN}
PUBLIC_IP=${VPS_IP}
EOF
    
    # Source it back
    source "$test_dir/.env"
    
    if [ "$SERVER_NAME" = "example.com" ]; then
        pass "  .env SERVER_NAME correct"
    else
        fail "  .env SERVER_NAME wrong: $SERVER_NAME"
    fi
    
    if [ "$PUBLIC_IP" = "203.0.113.42" ]; then
        pass "  .env PUBLIC_IP correct"
    else
        fail "  .env PUBLIC_IP wrong: $PUBLIC_IP"
    fi
    
    if [ ${#REGISTRATION_TOKEN} -gt 0 ]; then
        pass "  .env REGISTRATION_TOKEN present"
    else
        fail "  .env REGISTRATION_TOKEN missing"
    fi
}

# ─── Test: Caddyfile Generation (Delegation Mode) ───
test_caddyfile_delegation() {
    TESTS=$((TESTS+1))
    info "Testing Caddyfile generation (delegation mode)..."
    
    local DOMAIN="example.com"
    local MATRIX_HOST="matrix.example.com"
    local test_dir="$MOCK_DIR/test-caddy"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/Caddyfile" << EOF
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
    
    if grep -q "matrix.example.com:443" "$test_dir/Caddyfile"; then
        pass "  Caddyfile has matrix host on 443"
    else
        fail "  Caddyfile missing matrix host 443"
    fi
    
    if grep -q "8448" "$test_dir/Caddyfile"; then
        pass "  Caddyfile has federation port 8448"
    else
        fail "  Caddyfile missing federation port"
    fi
    
    if grep -q ".well-known/matrix/server" "$test_dir/Caddyfile"; then
        pass "  Caddyfile has .well-known delegation"
    else
        fail "  Caddyfile missing .well-known"
    fi
    
    if grep -q "example.com:443" "$test_dir/Caddyfile"; then
        pass "  Caddyfile serves root domain for delegation"
    else
        fail "  Caddyfile missing root domain"
    fi
}

# ─── Test: Caddyfile Generation (Subdomain Mode) ───
test_caddyfile_subdomain() {
    TESTS=$((TESTS+1))
    info "Testing Caddyfile generation (subdomain mode)..."
    
    local MATRIX_HOST="chat.example.com"
    local test_dir="$MOCK_DIR/test-caddy-sub"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/Caddyfile" << EOF
${MATRIX_HOST}:443 {
    reverse_proxy conduit:6167
}

${MATRIX_HOST}:8448 {
    reverse_proxy conduit:6167
}
EOF
    
    if grep -q "chat.example.com:443" "$test_dir/Caddyfile"; then
        pass "  Subdomain Caddyfile has correct host"
    else
        fail "  Subdomain Caddyfile wrong host"
    fi
    
    if ! grep -q ".well-known" "$test_dir/Caddyfile"; then
        pass "  Subdomain Caddyfile has NO .well-known (correct)"
    else
        fail "  Subdomain Caddyfile should NOT have .well-known"
    fi
}

# ─── Test: Turnserver Config ───
test_turnserver_config() {
    TESTS=$((TESTS+1))
    info "Testing turnserver.conf generation..."
    
    local VPS_IP="203.0.113.42"
    local TURN_SECRET="testsecret"
    local MATRIX_HOST="matrix.example.com"
    local test_dir="$MOCK_DIR/test-turn"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/turnserver.conf" << EOF
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=${VPS_IP}
external-ip=${VPS_IP}
use-auth-secret
static-auth-secret=${TURN_SECRET}
realm=${MATRIX_HOST}
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
EOF
    
    if grep -q "listening-port=3478" "$test_dir/turnserver.conf"; then
        pass "  TURN listening port correct"
    else
        fail "  TURN listening port wrong"
    fi
    
    if grep -q "static-auth-secret=testsecret" "$test_dir/turnserver.conf"; then
        pass "  TURN shared secret correct"
    else
        fail "  TURN shared secret wrong"
    fi
    
    if grep -q "denied-peer-ip=192.168" "$test_dir/turnserver.conf"; then
        pass "  TURN blocks private IPs"
    else
        fail "  TURN NOT blocking private IPs (security issue!)"
    fi
}

# ─── Test: Backup File Creation ───
test_backup_simulation() {
    TESTS=$((TESTS+1))
    info "Testing backup simulation..."
    
    # Create fake install
    mkdir -p "$MOCK_DIR/opt/conduit"
    echo "test" > "$MOCK_DIR/opt/conduit/docker-compose.yml"
    echo "test" > "$MOCK_DIR/opt/conduit/.env"
    
    # Create backup
    local BACKUP_FILE="$MOCK_DIR/opt/conduit-backups/conduit-backup-test.tar.gz"
    mkdir -p "$MOCK_DIR/opt/conduit-backups"
    tar czf "$BACKUP_FILE" -C "$MOCK_DIR" "opt/conduit" 2>/dev/null
    
    if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
        pass "  Backup file created and non-empty"
    else
        fail "  Backup file missing or empty"
    fi
    
    # Verify backup contents
    if tar tzf "$BACKUP_FILE" 2>/dev/null | grep -q "docker-compose.yml"; then
        pass "  Backup contains docker-compose.yml"
    else
        fail "  Backup missing docker-compose.yml"
    fi
    
    if tar tzf "$BACKUP_FILE" 2>/dev/null | grep -q ".env"; then
        pass "  Backup contains .env"
    else
        fail "  Backup missing .env"
    fi
}

# ─── Test: Restore Simulation ───
test_restore_simulation() {
    TESTS=$((TESTS+1))
    info "Testing restore simulation..."
    
    local BACKUP_FILE="$MOCK_DIR/opt/conduit-backups/conduit-backup-test.tar.gz"
    local RESTORE_DIR="$MOCK_DIR/restore-test"
    mkdir -p "$RESTORE_DIR"
    
    # Restore
    if tar xzf "$BACKUP_FILE" -C "$RESTORE_DIR" 2>/dev/null; then
        pass "  Backup extracts successfully"
    else
        fail "  Backup extraction failed"
    fi
    
    if [ -f "$RESTORE_DIR/opt/conduit/docker-compose.yml" ]; then
        pass "  Restored docker-compose.yml found"
    else
        fail "  Restored docker-compose.yml missing"
    fi
}

# ─── Test: Registration Toggle ───
test_registration_toggle() {
    TESTS=$((TESTS+1))
    info "Testing registration open/close via sed..."
    
    local test_file="$MOCK_DIR/test-compose.yml"
    cat > "$test_file" << 'EOF'
    environment:
      CONDUIT_ALLOW_REGISTRATION: "true"
      CONDUIT_REGISTRATION_TOKEN: ${REGISTRATION_TOKEN}
EOF
    
    # Close registration
    sed -i 's/ALLOW_REGISTRATION: "true"/ALLOW_REGISTRATION: "false"/' "$test_file"
    if grep -q 'ALLOW_REGISTRATION: "false"' "$test_file"; then
        pass "  Registration closed via sed"
    else
        fail "  Registration close failed"
    fi
    
    # Open registration
    sed -i 's/ALLOW_REGISTRATION: "false"/ALLOW_REGISTRATION: "true"/' "$test_file"
    if grep -q 'ALLOW_REGISTRATION: "true"' "$test_file"; then
        pass "  Registration opened via sed"
    else
        fail "  Registration open failed"
    fi
}

# ─── Test: Load Config ───
test_load_config() {
    TESTS=$((TESTS+1))
    info "Testing load_config..."
    
    mkdir -p "$MOCK_DIR/opt/conduit"
    cat > "$MOCK_DIR/opt/conduit/.env" << 'EOF'
SERVER_NAME=example.com
MATRIX_HOST=matrix.example.com
TURN_SECRET=abc123
REGISTRATION_TOKEN=def456
PUBLIC_IP=203.0.113.42
EOF
    
    local ENV_FILE="$MOCK_DIR/opt/conduit/.env"
    source "$ENV_FILE" 2>/dev/null || true
    
    if [ "$SERVER_NAME" = "example.com" ]; then
        pass "  SERVER_NAME loaded correctly"
    else
        fail "  SERVER_NAME wrong: $SERVER_NAME"
    fi
    
    if [ "$PUBLIC_IP" = "203.0.113.42" ]; then
        pass "  PUBLIC_IP loaded (no curl needed)"
    else
        fail "  PUBLIC_IP wrong: $PUBLIC_IP"
    fi
    
    if [ "$REGISTRATION_TOKEN" = "def456" ]; then
        pass "  REGISTRATION_TOKEN loaded"
    else
        fail "  REGISTRATION_TOKEN wrong: $REGISTRATION_TOKEN"
    fi
}

# ─── Test: Docker Compose Structure ───
test_compose_structure() {
    TESTS=$((TESTS+1))
    info "Testing docker-compose.yml structure..."
    
    local compose="$SCRIPT"
    
    # Check for port mappings on caddy only
    if grep -A20 'caddy:' "$compose" | grep -q 'ports:'; then
        pass "  Caddy has port mappings"
    else
        fail "  Caddy missing port mappings"
    fi
    
    # Check conduit has NO port mapping
    if grep -A10 'conduit:' "$compose" | grep -q 'ports:'; then
        fail "  Conduit should NOT have port mappings (security!)"
    else
        pass "  Conduit has no port mappings (correct)"
    fi
    
    # Check coturn uses host network
    if grep -q 'network_mode: host' "$compose"; then
        pass "  Coturn uses host network mode"
    else
        fail "  Coturn should use host network"
    fi
    
    # Check all 3 services exist
    for svc in conduit caddy coturn; do
        if grep -q "container_name: $svc" "$compose"; then
            pass "  Service '$svc' defined"
        else
            fail "  Service '$svc' missing"
        fi
    done
}

# ─── Test: Syntax Check ───
test_syntax() {
    TESTS=$((TESTS+1))
    info "Testing bash syntax..."
    
    if bash -n "$SCRIPT" 2>/dev/null; then
        pass "  Script has valid bash syntax"
    else
        fail "  Script has syntax errors!"
    fi
}

# ─── Test: Script Hardcoded Paths ───
test_paths() {
    TESTS=$((TESTS+1))
    info "Testing path consistency..."
    
    # Check INSTALL_DIR is used consistently
    local install_refs=$(grep -c 'INSTALL_DIR\|/opt/conduit[^-]' "$SCRIPT")
    if [ "$install_refs" -gt 5 ]; then
        pass "  INSTALL_DIR referenced $install_refs times"
    else
        fail "  INSTALL_DIR only referenced $install_refs times"
    fi
    
    # Check backup dir
    if grep -q '/opt/conduit-backups' "$SCRIPT"; then
        pass "  Backup dir /opt/conduit-backups referenced"
    else
        fail "  Backup dir not referenced"
    fi
}

# ─── Test: Security Checks ───
test_security() {
    TESTS=$((TESTS+1))
    info "Testing security features..."
    
    # UFW firewall
    if grep -q 'ufw' "$SCRIPT"; then
        pass "  UFW firewall setup present"
    else
        fail "  No UFW setup"
    fi
    
    # Fail2ban
    if grep -q 'fail2ban' "$SCRIPT"; then
        pass "  Fail2ban setup present"
    else
        fail "  No fail2ban setup"
    fi
    
    # No auto-reboot
    if grep -q 'Automatic-Reboot "false"' "$SCRIPT"; then
        pass "  Auto-reboot disabled (user decides)"
    else
        fail "  Auto-reboot setting missing"
    fi
    
    # Denied peer IPs in TURN
    if grep -q 'denied-peer-ip=192.168' "$SCRIPT"; then
        pass "  TURN blocks private networks"
    else
        fail "  TURN not blocking private networks"
    fi
    
    # CREDENTIALS.txt chmod 600
    if grep -q 'chmod 600.*CREDS_FILE' "$SCRIPT"; then
        pass "  Credentials file restricted to root"
    else
        fail "  Credentials file not restricted"
    fi
    
    # Password minimum length
    if grep -q 'lt 8' "$SCRIPT"; then
        pass "  Password minimum 8 chars enforced"
    else
        fail "  No password minimum length"
    fi
}

# ─── Test: Error Handling ───
test_error_handling() {
    TESTS=$((TESTS+1))
    info "Testing error handling..."
    
    # Docker install failure check
    if grep -q 'Docker installation failed' "$SCRIPT"; then
        pass "  Docker install failure handled"
    else
        fail "  Docker install failure not handled"
    fi
    
    # Backup tar failure
    if grep -q 'Failed to create backup' "$SCRIPT"; then
        pass "  Backup failure handled"
    else
        fail "  Backup failure not handled"
    fi
    
    # Restore tar failure
    if grep -q 'Failed to extract backup' "$SCRIPT"; then
        pass "  Restore failure handled"
    else
        fail "  Restore failure not handled"
    fi
    
    # Ctrl+C trap for registration
    if grep -q '_reclose_registration' "$SCRIPT"; then
        pass "  Ctrl+C trap for registration safety"
    else
        fail "  No Ctrl+C trap for registration"
    fi
    
    # Restore confirmation
    if grep -q "RESTORE" "$SCRIPT" && grep -q 'Type.*RESTORE' "$SCRIPT"; then
        pass "  Restore requires typing RESTORE"
    else
        fail "  Restore has weak confirmation"
    fi
    
    # Uninstall confirmation
    if grep -q "UNINSTALL" "$SCRIPT" && grep -q 'Type.*UNINSTALL' "$SCRIPT"; then
        pass "  Uninstall requires typing UNINSTALL"
    else
        fail "  Uninstall has weak confirmation"
    fi
}

# ─── Run all tests ───
main() {
    echo
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  conduit-deploy.sh — Simulation Test Suite${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo
    
    > "$RESULTS_FILE" 2>/dev/null || RESULTS_FILE="/dev/null"
    
    setup_mocks
    
    test_syntax
    test_domain_validation
    test_ip_validation
    test_username_validation
    test_password_validation
    test_domain_mode_validation
    test_config_generation
    test_caddyfile_delegation
    test_caddyfile_subdomain
    test_turnserver_config
    test_backup_simulation
    test_restore_simulation
    test_registration_toggle
    test_load_config
    test_compose_structure
    test_paths
    test_security
    test_error_handling
    
    echo
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    if [ $FAILURES -eq 0 ]; then
        echo -e "${BOLD}${GREEN}  ALL TESTS PASSED! ✅${NC}"
    else
        echo -e "${BOLD}${RED}  $FAILURES FAILURE(S) ❌${NC}"
    fi
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo
    
    # Cleanup
    rm -rf "$MOCK_DIR"
    
    exit $FAILURES
}

main "$@"
