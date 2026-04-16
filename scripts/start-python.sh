#!/bin/bash
# =============================================================================
# EDOT Workshop — Start Python backend (uninstrumented)
#
# Runs the Python backend in the background. Shell remains free.
# Output is written to logs/python.log.
#
# Workshop step: baseline — no telemetry is sent to Elastic.
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
        rm -f "$PID_FILE"  # stale PID file
    fi
fi

mkdir -p "$LOG_DIR"
cd "$ROOT_DIR/python-backend"

# ── Create venv if missing ─────────────────────────────────────────────────
if [ ! -d "venv" ]; then
    info "Creating Python virtual environment..."
    python3 -m venv venv
    info "Installing dependencies..."
    ./venv/bin/pip install -q -r requirements.txt
    info "  ✓ Dependencies installed"
fi

# ── Start ──────────────────────────────────────────────────────────────────
info "Starting Python backend (uninstrumented)..."

nohup ./venv/bin/uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    > "$LOG_DIR/python.log" 2>&1 &

echo $! > "$PID_FILE"

echo ""
echo "  ┌──────────────────────────────────────────────────────┐"
echo "  │  Python backend running (no instrumentation)          │"
echo "  │                                                        │"
echo "  │  API  : http://localhost:8000                          │"
echo "  │  Docs : http://localhost:8000/docs                     │"
echo "  │  Log  : tail -f logs/python.log                        │"
echo "  │  Stop : ./scripts/stop-python.sh                       │"
echo "  └──────────────────────────────────────────────────────┘"
echo ""
