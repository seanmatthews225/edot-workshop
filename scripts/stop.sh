#!/bin/bash
# =============================================================================
# EDOT Workshop — Stop all running services
#
# Usage:
#   ./scripts/stop.sh
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "  ${GREEN}✓${NC}  $*"; }
warn() { echo -e "  ${YELLOW}!${NC}  $*"; }

echo ""
echo -e "${BOLD}▸ Stopping services${NC}"

stopped=0
for name in java python; do
    PID_FILE="$REPO_DIR/.pid-$name"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            info "$name (PID $PID) stopped"
        else
            warn "$name PID $PID was not running"
        fi
        rm -f "$PID_FILE"
        stopped=$((stopped + 1))
    fi
done

if [ "$stopped" -eq 0 ]; then
    warn "No PID files found — services may not have been started with these scripts"
fi

echo ""
