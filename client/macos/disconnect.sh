#!/usr/bin/env bash
set -euo pipefail
sudo wg-quick down wg0
echo "Disconnected."
