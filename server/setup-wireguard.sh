#!/usr/bin/env bash
# Idempotent WireGuard server setup for Oracle Linux (dnf-based).
# Safe to re-run: skips steps that are already done.
set -euo pipefail

WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.8.0.1/24}"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/wg0.conf"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (sudo $0)" >&2
  exit 1
fi

if ! command -v wg >/dev/null 2>&1; then
  # wireguard-tools ships in OL9's own appstream repo -- no EPEL needed.
  # Scoping to just these two repos avoids dnf resolving against the full
  # repo set, which matters on the 1GB Always-Free micro shape (dnf's
  # solver can OOM against the full metadata set on that little RAM).
  dnf install -y --disablerepo="*" --enablerepo="ol9_baseos_latest" --enablerepo="ol9_appstream" wireguard-tools
fi

mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

if [[ ! -f "${WG_DIR}/privatekey" ]]; then
  umask 077
  wg genkey | tee "${WG_DIR}/privatekey" | wg pubkey > "${WG_DIR}/publickey"
fi

PRIVATE_KEY="$(cat "${WG_DIR}/privatekey")"
PRIMARY_IFACE="$(ip route show default | awk '/default/ {print $5; exit}')"

if [[ ! -f "$WG_CONF" ]]; then
  cat > "$WG_CONF" <<EOF
[Interface]
Address = ${WG_SUBNET}
ListenPort = ${WG_PORT}
PrivateKey = ${PRIVATE_KEY}
PostUp = iptables -t nat -A POSTROUTING -o ${PRIMARY_IFACE} -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o ${PRIMARY_IFACE} -j MASQUERADE

EOF
  chmod 600 "$WG_CONF"
fi

# Enable IP forwarding (persisted).
if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.d/99-wireguard.conf 2>/dev/null; then
  echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
  sysctl --system >/dev/null
fi

# Oracle Linux ships firewalld on by default; the OCI security list allowing
# the port does NOT open the host's own local firewall too.
if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port="${WG_PORT}/udp" >/dev/null
  firewall-cmd --permanent --zone=trusted --add-interface=wg0 >/dev/null 2>&1 || true
  firewall-cmd --permanent --zone=trusted --add-masquerade >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null
fi

systemctl enable --now wg-quick@wg0

echo "WireGuard server is up."
echo "Server public key: $(cat "${WG_DIR}/publickey")"
echo "Listening on UDP ${WG_PORT}, tunnel subnet ${WG_SUBNET}"
