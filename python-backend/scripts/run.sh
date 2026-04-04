#!/bin/bash
# Run the Python backend WITHOUT instrumentation

set -e

cd "$(dirname "$0")/.."

echo "=== Starting Python Backend (uninstrumented) ==="
echo "  URL    : http://localhost:8000"
echo "  API Doc: http://localhost:8000/docs"
echo "  Press Ctrl+C to stop"
echo ""

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
