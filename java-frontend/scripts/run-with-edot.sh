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

    # Resolve the latest version from the GitHub API.
    # The release asset is named elastic-otel-javaagent-{VERSION}.jar — there is
    # no unversioned filename, so we must look up the version first.
    EDOT_VERSION=$(curl -sf https://api.github.com/repos/elastic/elastic-otel-java/releases/latest \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"v\([^"]*\)".*/\1/')

    if [ -z "$EDOT_VERSION" ]; then
        echo ""
        echo "ERROR: Could not resolve the latest EDOT Java version from the GitHub API."
        echo "  Check your network connection, or download manually:"
        echo "  https://github.com/elastic/elastic-otel-java/releases/latest"
        echo "  Place the jar in this directory and rename it to: $AGENT"
        exit 1
    fi

    # Download from Maven Central — more stable than GitHub release asset URLs.
    DOWNLOAD_URL="https://repo1.maven.org/maven2/co/elastic/otel/elastic-otel-javaagent/${EDOT_VERSION}/elastic-otel-javaagent-${EDOT_VERSION}.jar"

    echo "  Version : $EDOT_VERSION"
    echo "  Source  : $DOWNLOAD_URL"

    curl -Lf -o "$AGENT" "$DOWNLOAD_URL" || {
        echo ""
        echo "ERROR: Download failed. Please download manually:"
        echo "  $DOWNLOAD_URL"
        echo "  Place the jar here and rename it to: $AGENT"
        rm -f "$AGENT"
        exit 1
    }

    echo "  ✓ Downloaded $AGENT (v${EDOT_VERSION})"
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
