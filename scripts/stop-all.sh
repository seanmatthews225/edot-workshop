#!/bin/bash
# Stop all workshop services

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/stop-java.sh"
"$SCRIPT_DIR/stop-python.sh"
