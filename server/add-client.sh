#!/usr/bin/env bash
# Run on the WireGuard server (as root) to provision a new client peer.
# Usage: ./add-client.sh <client-name>
set -euo pipefail

WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/wg0.conf"
CLIENTS_DIR="${WG_DIR}/clients"
WG_PORT="${WG_PORT:-51820}"
DNS="${DNS:-1.1.1.1}"

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <client-name>" >&2
  exit 1
fi
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (sudo $0 $NAME)" >&2
  exit 1
fi
if [[ ! -f "$WG_CONF" ]]; then
  echo "No $WG_CONF found. Run setup-wireguard.sh first." >&2
  exit 1
fi

mkdir -p "$CLIENTS_DIR"
chmod 700 "$CLIENTS_DIR"

if [[ -f "${CLIENTS_DIR}/${NAME}.conf" ]]; then
  echo "Client '${NAME}' already exists at ${CLIENTS_DIR}/${NAME}.conf" >&2
  exit 1
fi

SERVER_PUBKEY="$(cat "${WG_DIR}/publickey")"

# Find the next free host in 10.8.0.0/24, starting at .2 (.1 is the server).
USED_OCTETS="$(grep -oE '10\.8\.0\.[0-9]+' "$WG_CONF" | awk -F. '{print $4}' | sort -n)"
NEXT=2
for octet in $USED_OCTETS; do
  if [[ "$octet" -eq "$NEXT" ]]; then
    NEXT=$((NEXT + 1))
  fi
done
if [[ "$NEXT" -gt 254 ]]; then
  echo "No free addresses left in 10.8.0.0/24" >&2
  exit 1
fi
CLIENT_IP="10.8.0.${NEXT}"

umask 077
CLIENT_PRIVATE_KEY="$(wg genkey)"
CLIENT_PUBLIC_KEY="$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)"

SERVER_ENDPOINT="$(curl -s -4 --max-time 5 ifconfig.co || true)"
if [[ -z "$SERVER_ENDPOINT" ]]; then
  echo "Could not auto-detect public IP; pass it manually: SERVER_ENDPOINT=1.2.3.4 $0 $NAME" >&2
  SERVER_ENDPOINT="${SERVER_ENDPOINT:-REPLACE_WITH_SERVER_PUBLIC_IP}"
fi

# Append the new peer to the server config and hot-reload (no downtime for existing peers).
{
  echo ""
  echo "[Peer]"
  echo "# ${NAME}"
  echo "PublicKey = ${CLIENT_PUBLIC_KEY}"
  echo "AllowedIPs = ${CLIENT_IP}/32"
} >> "$WG_CONF"

wg syncconf wg0 <(wg-quick strip wg0)

cat > "${CLIENTS_DIR}/${NAME}.conf" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/32
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = ${SERVER_ENDPOINT}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
chmod 600 "${CLIENTS_DIR}/${NAME}.conf"

echo "Created client '${NAME}' with address ${CLIENT_IP}"
echo "Config: ${CLIENTS_DIR}/${NAME}.conf"
echo ""
echo "--- Copy this to your client (e.g. scp) ---"
cat "${CLIENTS_DIR}/${NAME}.conf"
echo "--------------------------------------------"
echo ""
if command -v qrencode >/dev/null 2>&1; then
  echo "Scan this QR code with the WireGuard mobile app:"
  qrencode -t ansiutf8 < "${CLIENTS_DIR}/${NAME}.conf"
  qrencode -o "${CLIENTS_DIR}/${NAME}.png" < "${CLIENTS_DIR}/${NAME}.conf"
  echo "(also saved as ${CLIENTS_DIR}/${NAME}.png)"
else
  echo "qrencode not installed on this server (by design -- it's an EPEL"
  echo "package, skipped to avoid dnf memory pressure on this micro shape)."
  echo "Fetch the .conf above to your Mac and run 'qrencode' there instead,"
  echo "e.g.: scp this server:${CLIENTS_DIR}/${NAME}.conf . && qrencode -t ansiutf8 < ${NAME}.conf"
fi
