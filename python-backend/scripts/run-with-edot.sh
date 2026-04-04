#!/bin/bash
# Run the Python backend WITH EDOT auto-instrumentation
#
# USAGE:
#   export OTEL_EXPORTER_OTLP_ENDPOINT="https://<your-deployment>.apm.<region>.cloud.es.io"
#   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=ApiKey <your-api-key>"
#   ./scripts/run-with-edot.sh

set -e

cd "$(dirname "$0")/.."

# ── Validate prerequisites ──────────────────────────────────────────────────
if ! python3 -c "import elastic_opentelemetry" 2>/dev/null; then
    echo "ERROR: EDOT Python not installed."
    echo ""
    echo "  Run: pip install elastic-opentelemetry"
    echo "  Then: edot-bootstrap --action=install"
    echo ""
    exit 1
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
export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-python-backend}"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=workshop,service.version=1.0.0"

echo "=== Starting Python Backend WITH EDOT Instrumentation ==="
echo "  Service Name : $OTEL_SERVICE_NAME"
echo "  OTLP Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  URL          : http://localhost:8000"
echo "  API Doc      : http://localhost:8000/docs"
echo "  Press Ctrl+C to stop"
echo ""

opentelemetry-instrument \
    uvicorn main:app --host 0.0.0.0 --port 8000
