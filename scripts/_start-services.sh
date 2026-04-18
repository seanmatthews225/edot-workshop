#!/bin/bash
# =============================================================================
# EDOT Workshop — Internal service launcher (do not call directly)
#
# Called by start.sh, start-java-edot.sh, start-full-edot.sh
#
# Args:
#   $1  JAVA_EDOT   — "true" to attach the EDOT Java agent, "false" otherwise
#   $2  PYTHON_EDOT — "true" to wrap Python with opentelemetry-instrument
#
# Assumes OTEL_EXPORTER_OTLP_ENDPOINT / _HEADERS / _PROTOCOL are already
# exported in the calling environment (sourced from .env.otel).
# =============================================================================

JAVA_EDOT="${1:-false}"
PYTHON_EDOT="${2:-false}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}!${NC}  $*"; }
error()   { echo -e "  ${RED}✗${NC}  $*"; exit 1; }
section() { echo -e "\n${BOLD}▸ $*${NC}"; }

# ── Guard: stop if already running ─────────────────────────────────────────
if [ -f "$REPO_DIR/.pid-python" ] || [ -f "$REPO_DIR/.pid-java" ]; then
    warn "Services appear to be running already. Run ./scripts/stop.sh first."
    exit 1
fi

mkdir -p "$REPO_DIR/logs"

# ── Start Python backend ────────────────────────────────────────────────────
section "Starting Python backend"

cd "$REPO_DIR/python-backend"

if [ "$PYTHON_EDOT" = "true" ]; then
    # Per-signal protocol variables are the most reliable way to force
    # http/protobuf on the Python OTel SDK.
    # Metrics are disabled — not part of this workshop.
    # Logs are enabled so Python logs appear in Elastic alongside Java logs.
    nohup env \
        OTEL_SERVICE_NAME=python-backend \
        OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT}" \
        OTEL_EXPORTER_OTLP_HEADERS="${OTEL_EXPORTER_OTLP_HEADERS}" \
        OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
        OTEL_EXPORTER_OTLP_TRACES_PROTOCOL="http/protobuf" \
        OTEL_EXPORTER_OTLP_LOGS_PROTOCOL="http/protobuf" \
        OTEL_METRICS_EXPORTER=none \
        OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop" \
        venv/bin/opentelemetry-instrument \
        venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 \
        > "$REPO_DIR/logs/python.log" 2>&1 &
    info "Python backend started with EDOT instrumentation (PID $!)"
else
    nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 \
        > "$REPO_DIR/logs/python.log" 2>&1 &
    info "Python backend started (no instrumentation, PID $!)"
fi

echo $! > "$REPO_DIR/.pid-python"

# Give Python a moment to bind before Java tries to connect
sleep 2

# ── Start Java frontend ─────────────────────────────────────────────────────
section "Starting Java frontend"

cd "$REPO_DIR/java-frontend"
JAR="target/java-frontend-1.0.0.jar"
[ -f "$JAR" ] || error "JAR not found: $JAR — run ./bootstrap.sh first"

if [ "$JAVA_EDOT" = "true" ]; then
    AGENT="$REPO_DIR/java-frontend/elastic-otel-javaagent.jar"
    [ -f "$AGENT" ] || error "EDOT Java agent not found — run ./bootstrap.sh first"

    nohup env \
        OTEL_SERVICE_NAME=java-frontend \
        OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT}" \
        OTEL_EXPORTER_OTLP_HEADERS="${OTEL_EXPORTER_OTLP_HEADERS}" \
        OTEL_EXPORTER_OTLP_PROTOCOL="${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}" \
        OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop" \
        java -javaagent:"$AGENT" -jar "$JAR" \
        > "$REPO_DIR/logs/java.log" 2>&1 &
    info "Java frontend started with EDOT instrumentation (PID $!)"
else
    nohup java -jar "$JAR" \
        > "$REPO_DIR/logs/java.log" 2>&1 &
    info "Java frontend started (no instrumentation, PID $!)"
fi

echo $! > "$REPO_DIR/.pid-java"

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Both services are running.${NC}"
echo -e "  App:  http://localhost:8080"
echo -e "  Logs: tail -f $REPO_DIR/logs/*.log"
echo -e "  Stop: ./scripts/stop.sh"
echo ""
