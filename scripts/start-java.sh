#!/bin/bash
# =============================================================================
# EDOT Workshop — Start Java frontend (uninstrumented)
#
# Builds (if needed) and runs the Java frontend in the background.
# Output is written to logs/java.log.
#
# Workshop step: baseline — no telemetry is sent to Elastic.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$SCRIPT_DIR/.pid-java"
LOG_DIR="$ROOT_DIR/logs"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Guard against double-start ─────────────────────────────────────────────
if [ -f "$PID_FILE" ]; then
    EXISTING_PID=$(cat "$PID_FILE")
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        warn "Java frontend is already running (PID $EXISTING_PID)."
        warn "Run ./scripts/stop-java.sh first."
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

mkdir -p "$LOG_DIR"
cd "$ROOT_DIR/java-frontend"

# ── Build if JAR is missing ────────────────────────────────────────────────
JAR="target/java-frontend-1.0.0.jar"
if [ ! -f "$JAR" ]; then
    info "JAR not found — building with Maven (this takes ~30 seconds)..."
    mvn -q clean package -DskipTests
    info "  ✓ Build complete"
fi

# ── Start ──────────────────────────────────────────────────────────────────
info "Starting Java frontend (uninstrumented)..."

nohup java -jar "$JAR" \
    > "$LOG_DIR/java.log" 2>&1 &

echo $! > "$PID_FILE"

echo ""
echo "  ┌──────────────────────────────────────────────────────┐"
echo "  │  Java frontend running (no instrumentation)           │"
echo "  │                                                        │"
echo "  │  UI   : http://localhost:8080                          │"
echo "  │  Log  : tail -f logs/java.log                          │"
echo "  │  Stop : ./scripts/stop-java.sh                         │"
echo "  └──────────────────────────────────────────────────────┘"
echo ""
