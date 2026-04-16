#!/bin/bash
# =============================================================================
# EDOT Workshop — Start Python backend WITH EDOT instrumentation
#
# Runs the Python backend in the background with OTel auto-instrumentation.
# Output is written to logs/python.log.
#
# Set Elastic credentials before running:
#   export OTEL_EXPORTER_OTLP_ENDPOINT="https://<your-apm-endpoint>"
#   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey <your-api-key>"
#
# Workshop step: after this, python-backend appears in the Elastic Service Map
# and distributed traces connect Java → Python → PostgreSQL.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$SCRIPT_DIR/.pid-python"
LOG_DIR="$ROOT_DIR/logs"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Guard against double-start ─────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
    EXISTING_PID=$(cat "$PID_FILE")
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        warn "Python backend is already running (PID $EXISTING_PID)."
        warn "Run ./scripts/stop-python.sh first."
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# ── Validate OTEL credentials ──────────────────────────────────────────────
[ -z "$OTEL_EXPORTER_OTLP_ENDPOINT" ] && \
    error "OTEL_EXPORTER_OTLP_ENDPOINT is not set.\n\n  export OTEL_EXPORTER_OTLP_ENDPOINT=\"https://<your-apm-endpoint>\"\n  export OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=ApiKey <your-api-key>\""

[ -z "$OTEL_EXPORTER_OTLP_HEADERS" ] && \
    error "OTEL_EXPORTER_OTLP_HEADERS is not set.\n\n  export OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=ApiKey <your-api-key>\""

mkdir -p "$LOG_DIR"
cd "$ROOT_DIR/python-backend"

# ── Create venv if missing ─────────────────────────────────────────────────
if [ ! -d "venv" ]; then
    info "Creating Python virtual environment..."
    python3 -m venv venv
    info "Installing dependencies..."
    ./venv/bin/pip install -q -r requirements.txt
fi

# ── Install EDOT Python if not present ────────────────────────────────────
if ! ./venv/bin/python -c "import elastic_opentelemetry" 2>/dev/null; then
    info "Installing EDOT Python (elastic-opentelemetry)..."
    ./venv/bin/pip install -q elastic-opentelemetry
    info "Running edot-bootstrap to install instrumentation libraries..."
    ./venv/bin/edot-bootstrap --action=install
    info "  ✓ EDOT Python installed"
else
    info "EDOT Python already installed"
fi

# ── Start ──────────────────────────────────────────────────────────────────
info "Starting Python backend WITH EDOT instrumentation..."

OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-python-backend}" \
OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop,service.version=1.0.0" \
nohup ./venv/bin/opentelemetry-instrument \
    ./venv/bin/uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    > "$LOG_DIR/python.log" 2>&1 &

echo $! > "$PID_FILE"

echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  Python backend running (EDOT instrumented)                   │"
echo "  │                                                                │"
echo "  │  Service name : python-backend                                 │"
echo "  │  OTLP endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  │                                                                │"
echo "  │  API  : http://localhost:8000                                  │"
echo "  │  Docs : http://localhost:8000/docs                             │"
echo "  │  Log  : tail -f logs/python.log                                │"
echo "  │  Stop : ./scripts/stop-python.sh                               │"
echo "  │                                                                │"
echo "  │  Open Elastic → Observability → Service Map                   │"
echo "  │  You should now see: java-frontend → python-backend            │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
