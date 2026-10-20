#!/usr/bin/env bash
# Install and bring up a WireGuard client config on macOS.
# Usage: ./connect.sh /path/to/client-name.conf
set -euo pipefail

CONF="${1:-}"
if [[ -z "$CONF" || ! -f "$CONF" ]]; then
  echo "Usage: $0 /path/to/client-name.conf" >&2
  exit 1
fi

if ! command -v wg-quick >/dev/null 2>&1; then
  echo "wireguard-tools not found. Install with: brew install wireguard-tools" >&2
  exit 1
fi

WG_ETC="$(brew --prefix)/etc/wireguard"
sudo mkdir -p "$WG_ETC"
sudo cp "$CONF" "${WG_ETC}/wg0.conf"
sudo chmod 600 "${WG_ETC}/wg0.conf"

sudo wg-quick up wg0
echo "Connected. Run status.sh to verify."
