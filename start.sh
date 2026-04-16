#!/bin/bash
# =============================================================================
# EDOT Workshop — Step 1: Start services (no instrumentation)
#
# Starts the Python backend and Java frontend in the background.
# Neither service sends any telemetry — this is the uninstrumented baseline.
#
# Usage:
#   ./start.sh
#
# Stop with:
#   ./stop.sh
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BOLD='\033[1m'; GREEN='\033[0;32m'; NC='\033[0m'

echo ""
echo -e "${BOLD}Starting services (no instrumentation)...${NC}"
echo ""

bash "$REPO_DIR/_start-services.sh" false false

echo ""
echo -e "  ${BOLD}App is running:${NC}"
echo -e "  Java frontend  →  http://localhost:8080"
echo -e "  Python API     →  http://localhost:8000/docs"
echo ""
echo -e "  Logs  :  tail -f logs/*.log"
echo -e "  Stop  :  ${GREEN}./stop.sh${NC}"
echo ""
