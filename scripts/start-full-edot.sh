#!/bin/bash
# =============================================================================
# EDOT Workshop — Step 3: Start services (Java + Python instrumented)
#
# Both services run with EDOT auto-instrumentation.
#
# In Elastic Observability you will now see:
#   - java-frontend AND python-backend in the Service Map
#   - Full distributed traces: Java → Python → PostgreSQL
#   - The traceparent header propagated across the service boundary
#   - Database spans showing the exact SQL queries Python runs
#
# Requires .env.otel to be filled in with your Elastic credentials.
#
# Usage:
#   ./start-full-edot.sh
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
echo -e "${BOLD}Starting services (Java + Python instrumented)...${NC}"
echo ""

bash "$REPO_DIR/_start-services.sh" true true

echo ""
echo -e "  ${BOLD}App is running:${NC}"
echo -e "  Java frontend  →  http://localhost:8080"
echo -e "  Python API     →  http://localhost:8000/docs"
echo ""
echo -e "  ${BOLD}In Elastic Observability:${NC}"
echo -e "  → Both java-frontend and python-backend visible in the Service Map"
echo -e "  → Click any trace to see the full span: Java → Python → PostgreSQL"
echo -e "  → The trace ID is the same across both services"
echo -e "  → SQL queries appear as child spans under Python"
echo ""
echo -e "  Logs  :  tail -f logs/*.log"
echo -e "  Stop  :  ${GREEN}./stop.sh${NC}"
echo ""
