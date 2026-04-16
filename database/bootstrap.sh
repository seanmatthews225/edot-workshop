#!/bin/bash
# =============================================================================
# EDOT Workshop - PostgreSQL Bootstrap Script
#
# Sets up everything PostgreSQL needs to run the workshop app:
#   - Creates the DB user (workshopuser)
#   - Creates the database (workshopdb)
#   - Creates the users table
#   - Seeds dummy records
#
# Run as a user with sudo access:
#   chmod +x database/bootstrap.sh
#   ./database/bootstrap.sh
#
# To reset (drop and recreate everything):
#   ./database/bootstrap.sh --reset
# =============================================================================

set -e

# ── Config (must match python-backend/database.py and application.properties) ─
DB_NAME="workshopdb"
DB_USER="workshopuser"
DB_PASS="workshoppass"
DB_HOST="localhost"
DB_PORT="5432"

# ── Colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo ""; echo -e "${GREEN}=== $* ===${NC}"; }

# ── Parse args ─────────────────────────────────────────────────────────────────
RESET=false
for arg in "$@"; do
    case $arg in
        --reset) RESET=true ;;
        --help|-h)
            echo "Usage: $0 [--reset]"
            echo "  --reset  Drop and recreate the database and user from scratch"
            exit 0
            ;;
    esac
done

# ── Check PostgreSQL is installed and running ──────────────────────────────────
section "Checking PostgreSQL"

if ! command -v psql &>/dev/null; then
    error "psql not found. Install PostgreSQL first:\n  sudo apt-get install postgresql postgresql-contrib"
fi

info "psql found: $(psql --version)"

# Try to start PostgreSQL if it isn't running
if ! sudo systemctl is-active --quiet postgresql 2>/dev/null; then
    warn "PostgreSQL service not running. Attempting to start..."
    sudo systemctl start postgresql || error "Could not start PostgreSQL. Check: sudo systemctl status postgresql"
fi

info "PostgreSQL service is running"

# ── Optional reset ─────────────────────────────────────────────────────────────
if [ "$RESET" = true ]; then
    section "Resetting (dropping existing DB and user)"
    warn "This will DELETE all data in '$DB_NAME'. Press Ctrl+C within 5 seconds to abort..."
    sleep 5
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $DB_NAME;" && info "Dropped database '$DB_NAME'"
    sudo -u postgres psql -c "DROP USER IF EXISTS $DB_USER;" && info "Dropped user '$DB_USER'"
fi

# ── Create DB user ─────────────────────────────────────────────────────────────
section "Creating database user"

USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';")

if [ "$USER_EXISTS" = "1" ]; then
    info "User '$DB_USER' already exists — skipping creation"
else
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    info "Created user '$DB_USER'"
fi

# ── Create database ────────────────────────────────────────────────────────────
section "Creating database"

DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';")

if [ "$DB_EXISTS" = "1" ]; then
    info "Database '$DB_NAME' already exists — skipping creation"
else
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    info "Created database '$DB_NAME'"
fi

# Grant privileges (idempotent)
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
info "Privileges granted"

# ── Create schema and seed data ────────────────────────────────────────────────
section "Creating schema and seeding data"

sudo -u postgres psql -d "$DB_NAME" << SQL

-- Grant schema-level permissions so the app user can create/alter objects
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;

-- Create the users table
CREATE TABLE IF NOT EXISTS users (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grant table ownership to workshopuser
ALTER TABLE users OWNER TO $DB_USER;
ALTER SEQUENCE users_id_seq OWNER TO $DB_USER;

-- Seed dummy data (25 records for a realistic dataset)
INSERT INTO users (name, email) VALUES
    ('Alice Johnson',     'alice@example.com'),
    ('Bob Smith',         'bob@example.com'),
    ('Carol White',       'carol@example.com'),
    ('David Martinez',    'david.martinez@example.com'),
    ('Eva Chen',          'eva.chen@example.com'),
    ('Frank Okafor',      'frank.okafor@example.com'),
    ('Grace Kim',         'grace.kim@example.com'),
    ('Hiro Tanaka',       'hiro.tanaka@example.com'),
    ('Isabelle Dupont',   'isabelle.dupont@example.com'),
    ('James Walker',      'james.walker@example.com'),
    ('Kira Patel',        'kira.patel@example.com'),
    ('Luca Ferrari',      'luca.ferrari@example.com'),
    ('Maria Santos',      'maria.santos@example.com'),
    ('Nathan Brooks',     'nathan.brooks@example.com'),
    ('Olivia Nguyen',     'olivia.nguyen@example.com'),
    ('Patrick O''Brien',  'patrick.obrien@example.com'),
    ('Quinn Zhao',        'quinn.zhao@example.com'),
    ('Rachel Adams',      'rachel.adams@example.com'),
    ('Samuel Diallo',     'samuel.diallo@example.com'),
    ('Tanya Ivanova',     'tanya.ivanova@example.com'),
    ('Umar Hassan',       'umar.hassan@example.com'),
    ('Vera Kowalski',     'vera.kowalski@example.com'),
    ('William Zhang',     'william.zhang@example.com'),
    ('Xena Morales',      'xena.morales@example.com'),
    ('Yuki Sato',         'yuki.sato@example.com')
ON CONFLICT (email) DO NOTHING;

SQL

info "Schema created and seed data inserted"

# ── Verify ─────────────────────────────────────────────────────────────────────
section "Verifying setup"

ROW_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM users;")
info "Rows in users table: $ROW_COUNT"

# Confirm the app user can connect
CONN_TEST=$(PGPASSWORD="$DB_PASS" psql \
    -h "$DB_HOST" -p "$DB_PORT" \
    -U "$DB_USER" -d "$DB_NAME" \
    -tAc "SELECT COUNT(*) FROM users;" 2>&1)

if echo "$CONN_TEST" | grep -qE '^[0-9]+$'; then
    info "App user connection test passed (count=$CONN_TEST)"
else
    warn "App user connection test returned: $CONN_TEST"
    warn "The DB is set up, but the app may need pg_hba.conf to allow local password auth."
    echo ""
    echo "  If you see 'peer authentication failed', run:"
    echo "    sudo nano /etc/postgresql/*/main/pg_hba.conf"
    echo "  Find this line:"
    echo "    local   all   all   peer"
    echo "  Change 'peer' to 'md5' or 'scram-sha-256', then restart:"
    echo "    sudo systemctl restart postgresql"
fi

# ── Done ───────────────────────────────────────────────────────────────────────
section "Bootstrap complete"
echo ""
echo "  Database : $DB_NAME"
echo "  User     : $DB_USER"
echo "  Password : $DB_PASS"
echo "  Host     : $DB_HOST:$DB_PORT"
echo ""
echo "  Connection string:"
echo "  postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""
info "You're ready to start the app. See docs/02-run-the-app.md"
