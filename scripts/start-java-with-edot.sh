#!/bin/bash
# =============================================================================
# EDOT Workshop — Start Java frontend WITH EDOT instrumentation
#
# Downloads the EDOT Java agent (if needed), then runs the Java frontend
# in the background with OTel auto-instrumentation active.
# Output is written to logs/java.log.
#
# Set Elastic credentials before running:
#   export OTEL_EXPORTER_OTLP_ENDPOINT="https://<your-apm-endpoint>"
#   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey <your-api-key>"
#
# Workshop step: after this, java-frontend appears in the Elastic Service Map.
# Calls to Python will show as uninstrumented external spans until Python
# is also instrumented with start-python-with-edot.sh.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$SCRIPT_DIR/.pid-java"
LOG_DIR="$ROOT_DIR/logs"
AGENT="$ROOT_DIR/java-frontend/elastic-otel-javaagent.jar"

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

# ── Validate OTEL credentials ──────────────────────────────────────────────
[ -z "$OTEL_EXPORTER_OTLP_ENDPOINT" ] && \
    error "OTEL_EXPORTER_OTLP_ENDPOINT is not set.\n\n  export OTEL_EXPORTER_OTLP_ENDPOINT=\"https://<your-apm-endpoint>\"\n  export OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=ApiKey <your-api-key>\""

[ -z "$OTEL_EXPORTER_OTLP_HEADERS" ] && \
    error "OTEL_EXPORTER_OTLP_HEADERS is not set.\n\n  export OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=ApiKey <your-api-key>\""

mkdir -p "$LOG_DIR"

# ── Download EDOT Java agent if needed ────────────────────────────────────
if [ ! -f "$AGENT" ]; then
    info "EDOT Java agent not found — downloading..."

    EDOT_VERSION=$(curl -sf https://api.github.com/repos/elastic/elastic-otel-java/releases/latest \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/')

    [ -z "$EDOT_VERSION" ] && \
        error "Could not resolve latest EDOT Java version.\n  Check your network, or download manually:\n  https://github.com/elastic/elastic-otel-java/releases/latest\n  Save the jar as: $AGENT"

    DOWNLOAD_URL="https://repo1.maven.org/maven2/co/elastic/otel/elastic-otel-javaagent/${EDOT_VERSION}/elastic-otel-javaagent-${EDOT_VERSION}.jar"
    info "  Version : $EDOT_VERSION"
    info "  Source  : $DOWNLOAD_URL"

    curl -Lf -o "$AGENT" "$DOWNLOAD_URL" || {
        rm -f "$AGENT"
        error "Download failed. Get the jar from:\n  $DOWNLOAD_URL\n  and save it as: $AGENT"
    }
    info "  ✓ Downloaded"
else
    info "EDOT Java agent already present — skipping download"
fi

# ── Build if JAR is missing ────────────────────────────────────────────────
cd "$ROOT_DIR/java-frontend"

JAR="target/java-frontend-1.0.0.jar"
if [ ! -f "$JAR" ]; then
    info "JAR not found — building with Maven (this takes ~30 seconds)..."
    mvn -q clean package -DskipTests
    info "  ✓ Build complete"
fi

# ── Start ──────────────────────────────────────────────────────────────────
info "Starting Java frontend WITH EDOT instrumentation..."

OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-java-frontend}" \
OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop,service.version=1.0.0" \
nohup java \
    -javaagent:"$AGENT" \
    -jar "$JAR" \
    > "$LOG_DIR/java.log" 2>&1 &

echo $! > "$PID_FILE"

echo ""
echo "  ┌──────────────────────────────────────────────────────────────┐"
echo "  │  Java frontend running (EDOT instrumented)                    │"
echo "  │                                                                │"
echo "  │  Service name : java-frontend                                  │"
echo "  │  OTLP endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  │                                                                │"
echo "  │  UI   : http://localhost:8080                                  │"
echo "  │  Log  : tail -f logs/java.log                                  │"
echo "  │  Stop : ./scripts/stop-java.sh                                 │"
echo "  │                                                                │"
echo "  │  Open Elastic → Observability → Service Map                   │"
echo "  │  You should see: java-frontend (Python calls = external)       │"
echo "  │                                                                │"
echo "  │  Next step: ./scripts/start-python-with-edot.sh               │"
echo "  └──────────────────────────────────────────────────────────────┘"
echo ""
