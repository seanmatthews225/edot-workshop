#!/bin/bash
# =============================================================================
# EDOT Workshop — Stop all services
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

stopped=0

for entry in java python; do
    PID_FILE="$REPO_DIR/.pid-$entry"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo -e "  ${GREEN}✓${NC}  Stopped $entry (PID $PID)"
            stopped=$((stopped + 1))
        else
            echo -e "  ${YELLOW}!${NC}  $entry (PID $PID) was not running"
        fi
        rm -f "$PID_FILE"
    fi
done

[ "$stopped" -eq 0 ] && echo -e "  ${YELLOW}!${NC}  No services were running"
echo ""
