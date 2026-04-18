#!/bin/bash
# =============================================================================
# EDOT Workshop — Bootstrap
#
# Run this ONCE before the workshop. It sets up everything:
#   - Makes all scripts executable
#   - Creates the PostgreSQL user, database, tables, and seed data
#   - Creates the Python virtual environment and installs dependencies
#   - Pre-installs EDOT Python instrumentation libraries
#   - Builds the Java JAR
#   - Downloads the EDOT Java agent
#   - Creates the .env.otel credentials file (fill in before instrumenting)
#
# Usage:
#   ./bootstrap.sh
# =============================================================================

set -e

# Prevent apt-get and needrestart from prompting for service restarts or
# debconf questions during package installation — without this the script
# hangs waiting for user input on a "Restart services?" dialog.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a        # auto-restart services without asking
export NEEDRESTART_SUSPEND=1     # suppress the needrestart banner entirely

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}!${NC}  $*"; }
error()   { echo -e "  ${RED}✗${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}▸ $*${NC}"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       EDOT Workshop — Bootstrap                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Make every script executable ────────────────────────────────────────
section "Making scripts executable"
find "$REPO_DIR" -name "*.sh" -exec chmod +x {} \;
info "All .sh files are now executable"

# ── 2. Install required tools ───────────────────────────────────────────────
section "Installing prerequisites"

# Verify we can use apt-get before attempting any installs
if ! command -v apt-get &>/dev/null; then
    echo -e "  ${RED}✗${NC}  apt-get not found — this script requires a Debian/Ubuntu system."
    echo "     Please install the following manually and re-run:"
    echo "       Java 17, Maven, Python 3, PostgreSQL, curl"
    exit 1
fi

install_if_missing() {
    local cmd="$1"
    local pkg="$2"
    local label="${3:-$pkg}"
    if command -v "$cmd" &>/dev/null; then
        info "$label already installed"
    else
        echo -e "  ${YELLOW}→${NC}  Installing $label..."
        sudo apt-get install -y -q "$pkg" > /dev/null
        info "$label installed"
    fi
}

sudo apt-get update -qq \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

install_if_missing java    openjdk-17-jdk          "Java 17"
install_if_missing mvn     maven                   "Maven"
install_if_missing python3 python3                 "Python 3"
install_if_missing pip3    python3-pip             "pip"
# python3-venv is required to create virtual environments
sudo apt-get install -y -q python3-venv > /dev/null
if command -v psql &>/dev/null; then
    info "PostgreSQL already installed"
else
    echo -e "  ${YELLOW}→${NC}  Installing PostgreSQL..."
    sudo apt-get install -y -q postgresql postgresql-contrib > /dev/null
    info "PostgreSQL installed"
fi
install_if_missing curl    curl                    "curl"

# ── 3. PostgreSQL setup ─────────────────────────────────────────────────────
section "Setting up PostgreSQL"

DB_NAME="workshopdb"
DB_USER="workshopuser"
DB_PASS="workshoppass"

# Start PostgreSQL if it isn't running
if ! sudo systemctl is-active --quiet postgresql 2>/dev/null; then
    warn "PostgreSQL not running — starting it..."
    sudo systemctl start postgresql
fi
info "PostgreSQL is running"

# All psql commands run from /tmp so the postgres system user (which cannot
# access /root or other restricted home directories) has a readable working dir.
pushd /tmp > /dev/null

# Create user
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" | grep -q 1; then
    info "Database user '$DB_USER' already exists"
else
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    info "Created database user '$DB_USER'"
fi

# Create database
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" | grep -q 1; then
    info "Database '$DB_NAME' already exists"
else
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    info "Created database '$DB_NAME'"
fi

# Schema, permissions, seed data
sudo -u postgres psql -d "$DB_NAME" -q << SQL
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;

CREATE TABLE IF NOT EXISTS users (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE users OWNER TO $DB_USER;
ALTER SEQUENCE users_id_seq OWNER TO $DB_USER;

INSERT INTO users (name, email) VALUES
    ('Alice Johnson',   'alice@example.com'),
    ('Bob Smith',       'bob@example.com'),
    ('Carol White',     'carol@example.com'),
    ('David Martinez',  'david.martinez@example.com'),
    ('Eva Chen',        'eva.chen@example.com'),
    ('Frank Okafor',    'frank.okafor@example.com'),
    ('Grace Kim',       'grace.kim@example.com'),
    ('Hiro Tanaka',     'hiro.tanaka@example.com'),
    ('Isabelle Dupont', 'isabelle.dupont@example.com'),
    ('James Walker',    'james.walker@example.com')
ON CONFLICT (email) DO NOTHING;
SQL

ROW_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM users;")
info "Schema ready — $ROW_COUNT rows in users table"

popd > /dev/null

# ── 4. Python virtual environment ───────────────────────────────────────────
section "Setting up Python environment"

cd "$REPO_DIR/python-backend"

if [ ! -d "venv" ]; then
    python3 -m venv venv
    info "Virtual environment created"
fi

venv/bin/pip install -q --upgrade pip
venv/bin/pip install -q -r requirements.txt
info "App dependencies installed"

# Pre-install EDOT Python so it's ready for the instrumentation steps
venv/bin/pip install -q elastic-opentelemetry
venv/bin/edot-bootstrap --action=install
info "EDOT Python (elastic-opentelemetry) installed and bootstrapped"

# ── 5. Build Java ───────────────────────────────────────────────────────────
section "Building Java frontend"

cd "$REPO_DIR/java-frontend"
mvn -q clean package -DskipTests
info "JAR built: java-frontend/target/java-frontend-1.0.0.jar"

# ── 6. Download EDOT Java agent ─────────────────────────────────────────────
section "Downloading EDOT Java agent"

AGENT="$REPO_DIR/java-frontend/elastic-otel-javaagent.jar"

if [ -f "$AGENT" ]; then
    info "EDOT Java agent already downloaded — skipping"
else
    EDOT_VERSION=$(curl -sf https://api.github.com/repos/elastic/elastic-otel-java/releases/latest \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/')

    [ -z "$EDOT_VERSION" ] && error "Could not resolve EDOT Java version from GitHub API. Check your network."

    DOWNLOAD_URL="https://repo1.maven.org/maven2/co/elastic/otel/elastic-otel-javaagent/${EDOT_VERSION}/elastic-otel-javaagent-${EDOT_VERSION}.jar"

    curl -Lf -o "$AGENT" "$DOWNLOAD_URL" || {
        rm -f "$AGENT"
        error "Agent download failed.\n     Download manually from: $DOWNLOAD_URL\n     Save as: $AGENT"
    }
    info "EDOT Java agent downloaded (v${EDOT_VERSION})"
fi

# ── 7. Create .env.otel credentials template ────────────────────────────────
section "OTEL credentials file"

ENV_FILE="$REPO_DIR/.env.otel"

if [ -f "$ENV_FILE" ]; then
    info ".env.otel already exists — skipping"
else
    cat > "$ENV_FILE" << 'EOF'
# ── Elastic OTEL credentials ────────────────────────────────────────────────
# Fill in the values below before running start-java-edot.sh or
# start-full-edot.sh.
#
# ⚠️  VERSION NOTE
#   EDOT SDKs are officially supported on Elastic Stack 8.18+.
#   If you are running 8.17 the core workshop experience — distributed
#   traces, service map, span waterfalls — still works because it uses
#   the standard OTLP protocol which APM Server has supported since 7.x.
#   A small number of EDOT-specific UI enhancements require 8.18+.
#
# ENDPOINT — URL of your APM Server:
#   http://<apm-server-host>:8200
#
# HEADERS — APM Server authentication.
#   Format is always:  HeaderName=HeaderValue
#
#   Secret token (most common for self-managed):
#     Authorization=Bearer <your-apm-secret-token>
#
#   No auth configured on APM Server:
#     Comment out OTEL_EXPORTER_OTLP_HEADERS entirely
#
#   Elastic Cloud (ApiKey auth):
#     Authorization=ApiKey <your-base64-api-key>
#
# Find your secret token in apm-server.yml:
#   apm-server.auth.secret_token: "<token>"
# or in Kibana: Fleet → Agent policies → <policy> → APM integration

OTEL_EXPORTER_OTLP_ENDPOINT="http://your-apm-server-host:8200"
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer your-apm-secret-token"

# HTTP protobuf is the recommended transport for APM Server 8.x
OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
EOF
    info ".env.otel template created — edit it with your APM Server details before instrumenting"
fi

# ── 8. Create logs dir ───────────────────────────────────────────────────────
mkdir -p "$REPO_DIR/logs"

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Bootstrap complete — workshop is ready                       ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║                                                                ║${NC}"
echo -e "${BOLD}║  Workshop steps:                                               ║${NC}"
echo -e "${BOLD}║                                                                ║${NC}"
echo -e "${BOLD}║  1. Baseline (no telemetry)                                    ║${NC}"
echo -e "${BOLD}║       ./start.sh                                               ║${NC}"
echo -e "${BOLD}║       ./stop.sh                                                ║${NC}"
echo -e "${BOLD}║                                                                ║${NC}"
echo -e "${BOLD}║  2. Instrument Java only                                       ║${NC}"
echo -e "${BOLD}║       Edit .env.otel with your Elastic credentials             ║${NC}"
echo -e "${BOLD}║       ./start-java-edot.sh                                     ║${NC}"
echo -e "${BOLD}║       ./stop.sh                                                ║${NC}"
echo -e "${BOLD}║                                                                ║${NC}"
echo -e "${BOLD}║  3. Instrument Java + Python                                   ║${NC}"
echo -e "${BOLD}║       ./start-full-edot.sh                                     ║${NC}"
echo -e "${BOLD}║       ./stop.sh                                                ║${NC}"
echo -e "${BOLD}║                                                                ║${NC}"
echo -e "${BOLD}║  Logs: tail -f logs/*.log                                      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
