#!/bin/bash
# Internal helper — called by start.sh, start-java-edot.sh, start-full-edot.sh.
# Not intended to be run directly.
#
# Arguments:
#   $1  JAVA_EDOT   "true" | "false"
#   $2  PYTHON_EDOT "true" | "false"

JAVA_EDOT="${1:-false}"
PYTHON_EDOT="${2:-false}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$REPO_DIR/logs"
PID_JAVA="$REPO_DIR/.pid-java"
PID_PYTHON="$REPO_DIR/.pid-python"
AGENT="$REPO_DIR/java-frontend/elastic-otel-javaagent.jar"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "  ${GREEN}✓${NC}  $*"; }
warn()  { echo -e "  ${YELLOW}!${NC}  $*"; }
error() { echo -e "  ${RED}✗${NC}  $*"; exit 1; }

# ── Guard: stop any already-running services ──────────────────────────────
for PID_FILE in "$PID_JAVA" "$PID_PYTHON"; do
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            SERVICE=$(basename "$PID_FILE" | sed 's/\.pid-//')
            error "The $SERVICE service is already running (PID $PID).\n     Run ./scripts/stop.sh first."
        else
            rm -f "$PID_FILE"  # stale
        fi
    fi
done

mkdir -p "$LOG_DIR"

# ── Common OTEL vars (sourced from .env.otel by the caller) ───────────────
# Passed explicitly into each nohup subshell so they survive the fork.
OTLP_ENV=(
    "OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT}"
    "OTEL_EXPORTER_OTLP_HEADERS=${OTEL_EXPORTER_OTLP_HEADERS}"
    "OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}"
    "OTEL_RESOURCE_ATTRIBUTES=deployment.environment=workshop"
)

# ── Start Python backend ──────────────────────────────────────────────────
cd "$REPO_DIR/python-backend"

if [ "$PYTHON_EDOT" = "true" ]; then
    env "${OTLP_ENV[@]}" \
        OTEL_SERVICE_NAME="python-backend" \
    nohup ./venv/bin/opentelemetry-instrument \
        ./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 \
        > "$LOG_DIR/python.log" 2>&1 &
    PYTHON_LABEL="with EDOT"
else
    nohup ./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 \
        > "$LOG_DIR/python.log" 2>&1 &
    PYTHON_LABEL="no instrumentation"
fi

echo $! > "$PID_PYTHON"
info "Python backend started ($PYTHON_LABEL)"

# Give Python a moment to bind the port before Java starts calling it
sleep 2

# ── Start Java frontend ───────────────────────────────────────────────────
cd "$REPO_DIR/java-frontend"

JAR="target/java-frontend-1.0.0.jar"
[ ! -f "$JAR" ] && error "JAR not found at java-frontend/$JAR — run ./bootstrap.sh first."

if [ "$JAVA_EDOT" = "true" ]; then
    [ ! -f "$AGENT" ] && error "EDOT Java agent not found — run ./bootstrap.sh first."
    env "${OTLP_ENV[@]}" \
        OTEL_SERVICE_NAME="java-frontend" \
    nohup java -javaagent:"$AGENT" -jar "$JAR" \
        > "$LOG_DIR/java.log" 2>&1 &
    JAVA_LABEL="with EDOT"
else
    nohup java -jar "$JAR" \
        > "$LOG_DIR/java.log" 2>&1 &
    JAVA_LABEL="no instrumentation"
fi

echo $! > "$PID_JAVA"
info "Java frontend started ($JAVA_LABEL)"
