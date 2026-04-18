#!/bin/bash
# =============================================================================
# EDOT Workshop — Step 3: Start with Java + Python both instrumented
#
# Both services run with EDOT agents attached.
# In Elastic you'll see the full distributed trace: Java → Python → PostgreSQL.
#
# Requires .env.otel to be filled in with your APM Server details.
#
# Usage:
#   ./scripts/start-full-edot.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_DIR/.env.otel"

RED='\033[0;31m'; NC='\033[0m'

if [ ! -f "$ENV_FILE" ]; then
    echo -e "  ${RED}✗${NC}  .env.otel not found — run ./bootstrap.sh first"
    exit 1
fi

set -a; source "$ENV_FILE"; set +a

if [[ "$OTEL_EXPORTER_OTLP_ENDPOINT" == *"your-apm-server"* ]]; then
    echo -e "  ${RED}✗${NC}  .env.otel still has placeholder values."
    echo "     Edit it with your APM Server details:"
    echo "       OTEL_EXPORTER_OTLP_ENDPOINT=\"http://<apm-server-host>:8200\""
    echo "       OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=Bearer <your-secret-token>\""
    exit 1
fi

"$SCRIPT_DIR/_start-services.sh" true true
