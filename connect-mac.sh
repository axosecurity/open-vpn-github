#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# OpenVPN + Cloudflare Tunnel 1-Click Connector for macOS
# -----------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN} 🚀 OpenVPN + Cloudflare Tunnel Connector for macOS${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Check for cloudflared
if ! command -v cloudflared &> /dev/null; then
  echo -e "${YELLOW}[!] cloudflared is not installed.${NC}"
  echo "    Installing via Homebrew..."
  brew install cloudflared
fi

# 2. Get Cloudflare Hostname
CF_HOSTNAME="${1:-}"
if [ -z "$CF_HOSTNAME" ]; then
  if [ -f ".cf_hostname" ]; then
    CF_HOSTNAME=$(cat .cf_hostname)
  fi
fi

if [ -z "$CF_HOSTNAME" ]; then
  read -rp "Enter your Cloudflare Tunnel Hostname (e.g. vpn.yourdomain.com): " CF_HOSTNAME
  echo "$CF_HOSTNAME" > .cf_hostname
fi

echo -e "${GREEN}[✓] Using Cloudflare Hostname:${NC} $CF_HOSTNAME"

# 3. Check for client.ovpn
OVPN_FILE="${2:-client.ovpn}"
if [ ! -f "$OVPN_FILE" ]; then
  echo -e "${RED}[✗] $OVPN_FILE not found in current directory!${NC}"
  echo "    Download 'openvpn-client-profile' artifact from your GitHub Actions run,"
  echo "    unzip it and place 'client.ovpn' in this folder."
  exit 1
fi
echo -e "${GREEN}[✓] Found OpenVPN profile:${NC} $OVPN_FILE"

# 4. Kill any previous cloudflared access tcp instances on port 1194
if lsof -ti:1194 &> /dev/null; then
  echo -e "${YELLOW}[!] Terminating existing process listening on port 1194...${NC}"
  kill -9 $(lsof -ti:1194) 2>/dev/null || true
fi

# 5. Start cloudflared access tcp in background
echo -e "${BLUE}[*] Starting cloudflared access bridge (127.0.0.1:1194 -> $CF_HOSTNAME)...${NC}"
cloudflared access tcp --hostname "$CF_HOSTNAME" --url 127.0.0.1:1194 > /tmp/cf-access.log 2>&1 &
CF_PID=$!

cleanup() {
  echo ""
  echo -e "${YELLOW}[*] Shutting down connection...${NC}"
  if kill -0 "$CF_PID" 2>/dev/null; then
    kill "$CF_PID" 2>/dev/null || true
  fi
  echo -e "${GREEN}[✓] Disconnected cleanly.${NC}"
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

sleep 2
if ! kill -0 "$CF_PID" 2>/dev/null; then
  echo -e "${RED}[✗] Failed to start cloudflared access! Logs:${NC}"
  cat /tmp/cf-access.log
  exit 1
fi
echo -e "${GREEN}[✓] Cloudflare Access bridge is ACTIVE (PID: $CF_PID).${NC}"

# 6. Launch OpenVPN
echo ""
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}🎉 Cloudflare Bridge Ready! Choose connection mode:${NC}"
echo -e "  1) Launch directly in Terminal (sudo openvpn)"
echo -e "  2) Open with OpenVPN Connect / Tunnelblick GUI app"
echo -e "${GREEN}======================================================${NC}"
read -rp "Select option [1 or 2] (default 1): " MODE
MODE="${MODE:-1}"

if [ "$MODE" = "1" ]; then
  if ! command -v openvpn &> /dev/null; then
    echo -e "${YELLOW}[!] openvpn CLI is not installed via brew. Installing...${NC}"
    brew install openvpn
  fi
  
  OPENVPN_BIN="$(brew --prefix openvpn)/sbin/openvpn"
  if [ ! -f "$OPENVPN_BIN" ]; then
    OPENVPN_BIN="openvpn"
  fi

  echo -e "${BLUE}[*] Connecting OpenVPN (requires sudo password)...${NC}"
  sudo "$OPENVPN_BIN" --config "$OVPN_FILE"
else
  echo -e "${BLUE}[*] Opening $OVPN_FILE in your default OpenVPN GUI app...${NC}"
  open "$OVPN_FILE"
  echo -e "${YELLOW}[!] Keep this terminal open while using the VPN! Press Ctrl+C to disconnect.${NC}"
  wait "$CF_PID"
fi
