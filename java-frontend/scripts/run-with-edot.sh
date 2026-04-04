#!/bin/bash
# Run the Java frontend service WITH EDOT auto-instrumentation
#
# USAGE:
#   export OTEL_EXPORTER_OTLP_ENDPOINT="https://<your-deployment>.apm.<region>.cloud.es.io"
#   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey <your-api-key>"
#   ./scripts/run-with-edot.sh

set -e

cd "$(dirname "$0")/.."

JAR="target/java-frontend-1.0.0.jar"
AGENT="elastic-otel-javaagent.jar"

# ── Validate prerequisites ──────────────────────────────────────────────────
if [ ! -f "$JAR" ]; then
    echo "JAR not found. Building first..."
    ./scripts/build.sh
fi

if [ ! -f "$AGENT" ]; then
    echo "EDOT Java agent not found. Downloading..."
    echo "  Source: https://github.com/elastic/elastic-otel-java/releases/latest"
    curl -L -o "$AGENT" \
        "https://github.com/elastic/elastic-otel-java/releases/latest/download/elastic-otel-javaagent.jar"
    echo "  ✓ Downloaded $AGENT"
fi

if [ -z "$OTEL_EXPORTER_OTLP_ENDPOINT" ]; then
    echo "ERROR: OTEL_EXPORTER_OTLP_ENDPOINT is not set."
    echo ""
    echo "  export OTEL_EXPORTER_OTLP_ENDPOINT=\"https://<your-apm-endpoint>\""
    echo "  export OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=ApiKey <your-api-key>\""
    echo ""
    exit 1
fi

if [ -z "$OTEL_EXPORTER_OTLP_HEADERS" ]; then
    echo "ERROR: OTEL_EXPORTER_OTLP_HEADERS is not set."
    echo ""
    echo "  export OTEL_EXPORTER_OTLP_HEADERS=\"Authorization=ApiKey <your-api-key>\""
    echo ""
    exit 1
fi

# ── Launch with EDOT ────────────────────────────────────────────────────────
export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-java-frontend}"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop,service.version=1.0.0"

echo "=== Starting Java Frontend WITH EDOT Instrumentation ==="
echo "  Service Name : $OTEL_SERVICE_NAME"
echo "  OTLP Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  URL          : http://localhost:8080"
echo "  Press Ctrl+C to stop"
echo ""

java \
    -javaagent:"$AGENT" \
    -jar "$JAR"
