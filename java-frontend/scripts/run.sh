#!/bin/bash
# Run the Java frontend service WITHOUT instrumentation

set -e

cd "$(dirname "$0")/.."

JAR="target/java-frontend-1.0.0.jar"

if [ ! -f "$JAR" ]; then
    echo "JAR not found. Building first..."
    ./scripts/build.sh
fi

echo "=== Starting Java Frontend (uninstrumented) ==="
echo "  URL: http://localhost:8080"
echo "  Press Ctrl+C to stop"
echo ""

java -jar "$JAR"
