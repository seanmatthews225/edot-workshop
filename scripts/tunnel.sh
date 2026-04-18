#!/bin/bash
# =============================================================================
# EDOT Workshop — Open a public tunnel to the Java frontend
#
# Uses localtunnel (via npx) to expose localhost:8080 as a public URL.
# The tunnel password is this machine's public IP address.
#
# Run AFTER starting the app with ./scripts/start.sh (or the EDOT variants).
#
# Usage:
#   ./scripts/tunnel.sh
# =============================================================================

if ! command -v npx &>/dev/null; then
    echo "Error: npx not found. Run ./bootstrap.sh first."
    exit 1
fi

echo ""
echo "The Local Tunnel Password = $(curl -s ipv4.icanhazip.com)"
echo ""
echo "Click the URL below and enter the above IP address in the Tunnel Password field."
echo ""

npx localtunnel --port 8080
