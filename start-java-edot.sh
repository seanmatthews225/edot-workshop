#!/bin/bash
# =============================================================================
# EDOT Workshop — Step 2: Start services (Java instrumented only)
#
# Java frontend runs with the EDOT Java agent.
# Python backend runs without instrumentation.
#
# In Elastic Observability you will see:
#   - java-frontend appears in the Service Map
#   - Calls from Java to Python show as uninstrumented external spans
#   - No python-backend service entry yet
#
# Requires .env.otel to be filled in with your Elastic credentials.
#
# Usage:
#   ./start-java-edot.sh
#
# Stop with:
#   ./stop.sh
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPO_DIR/.env.otel"
BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ── Load credentials ─────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error:${NC} .env.otel not found. Run ./bootstrap.sh first."
    exit 1
fi

set -a; source "$ENV_FILE"; set +a

if [ -z "$OTEL_EXPORTER_OTLP_ENDPOINT" ] || \
   [ "$OTEL_EXPORTER_OTLP_ENDPOINT" = "https://your-apm-endpoint.cloud.es.io" ]; then
    echo ""
    echo -e "${RED}Error:${NC} .env.otel has not been filled in yet."
    echo ""
    echo "  Open .env.otel and set:"
    echo "    OTEL_EXPORTER_OTLP_ENDPOINT  — your Elastic APM endpoint"
    echo "    OTEL_EXPORTER_OTLP_HEADERS   — Authorization=ApiKey <your-key>"
    echo ""
    exit 1
fi

# ── Start ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Starting services (Java instrumented, Python not)...${NC}"
echo ""

bash "$REPO_DIR/_start-services.sh" true false

echo ""
echo -e "  ${BOLD}App is running:${NC}"
echo -e "  Java frontend  →  http://localhost:8080"
echo -e "  Python API     →  http://localhost:8000/docs"
echo ""
echo -e "  ${BOLD}In Elastic Observability:${NC}"
echo -e "  → Service Map shows java-frontend"
echo -e "  → Python calls appear as external spans with no service detail"
echo -e "  → No python-backend service entry yet"
echo ""
echo -e "  Logs  :  tail -f logs/*.log"
echo -e "  Stop  :  ${GREEN}./stop.sh${NC}  (then run ./start-full-edot.sh to complete the picture)"
echo ""
