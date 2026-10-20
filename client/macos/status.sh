#!/usr/bin/env bash
set -euo pipefail

echo "--- WireGuard status ---"
sudo wg show || echo "Interface wg0 is not up."

echo ""
echo "--- Apparent public location ---"
curl -s https://ifconfig.co/country
echo ""
curl -s https://ifconfig.co
echo ""
