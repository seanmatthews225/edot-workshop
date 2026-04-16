#!/bin/bash
# Stop the Python backend

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/.pid-python"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

if [ ! -f "$PID_FILE" ]; then
    warn "Python backend does not appear to be running (no PID file)."
    exit 0
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    info "Stopped Python backend (PID $PID)"
else
    warn "Python backend (PID $PID) was not running"
fi

rm -f "$PID_FILE"
