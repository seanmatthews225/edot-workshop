#!/bin/bash
# =============================================================================
# EDOT Workshop — Step 2: Start services (Java instrumented only)
#
# Java runs with the EDOT agent. Python runs without instrumentation.
#
# What you'll see in Elastic Observability:
#   - java-frontend appears in the Service Map
#   - Calls to Python show as uninstrumented external spans (no service detail)
#   - python-backend does not appear yet
#
# Requires .env.otel to be filled in first.
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env.otel"
BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ── Load and validate credentials ─────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error:${NC} .env.otel not found. Run ./bootstrap.sh first."
    exit 1
fi

set -a; source "$ENV_FILE"; set +a

if [ -z "$OTEL_EXPORTER_OTLP_ENDPOINT" ] || \
   [[ "$OTEL_EXPORTER_OTLP_ENDPOINT" == *"your-apm-server"* ]]; then
    echo ""
    echo -e "${RED}Error:${NC} .env.otel has not been filled in yet."
    echo ""
    echo "  Edit .env.otel and set your APM Server details, e.g.:"
    echo ""
    echo "    OTEL_EXPORTER_OTLP_ENDPOINT=\"http://<apm-server-host>:8200\""
    echo "    OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=Bearer <secret-token>\""
    echo "    OTEL_EXPORTER_OTLP_PROTOCOL=\"http/protobuf\""
    echo ""
    exit 1
fi

# ── Start ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Starting services (Java instrumented, Python not)...${NC}"
echo ""

bash "$REPO_DIR/scripts/_start-services.sh" true false

echo ""
echo -e "  ${BOLD}App is running:${NC}"
echo -e "  Java frontend  →  http://localhost:8080"
echo -e "  Python API     →  http://localhost:8000/docs"
echo ""
echo -e "  ${BOLD}In Elastic Observability → Service Map:${NC}"
echo -e "  → java-frontend is visible"
echo -e "  → Python calls appear as external spans with no service detail"
echo ""
echo -e "  Logs  :  tail -f logs/*.log"
echo -e "  Stop  :  ${GREEN}./scripts/stop.sh${NC}  (then run ./scripts/start-full-edot.sh)"
echo ""
