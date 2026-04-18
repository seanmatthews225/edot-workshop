#!/bin/bash
# =============================================================================
# EDOT Workshop — Step 1: Start app with no instrumentation
#
# Both services start as normal processes — no EDOT agents attached.
# Nothing will appear in Elastic Observability.
#
# Usage:
#   ./scripts/start.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/_start-services.sh" false false
