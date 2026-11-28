#!/usr/bin/env bash
# ==============================================================================
# MycoLab - LiveKit WebRTC Video Streaming Server Installer voor Raspberry Pi
# ==============================================================================
# Installeert en configureert de officiële LiveKit WebRTC server op poort 7880
# zodat je kweekcamera direct over lokaal Wi-Fi en 4G/5G in HD streamt.
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
cat << "EOF"
  __  __                  _           _     
 |  \/  |                | |         | |    
 | \  / |_   _  ___ ___  | |     __ _| |__  
 | |\/| | | | |/ __/ _ \ | |    / _` | '_ \ 
 | |  | | |_| | (_| (_) || |___| (_| | |_) |
 |_|  |_|\__, |\___\___/ |______\__,_|_.__/ 
          __/ |  LiveKit WebRTC Stream Server
         |___/   voor Raspberry Pi
EOF
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Voer dit script uit met root-rechten:${NC}"
    echo -e "   ${BOLD}sudo bash install_livekit.sh${NC}"
    exit 1
fi

PI_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
PI_USER="${PI_USER:-pi}"

# 1. Check architectuur (arm64 of armv7)
ARCH=$(uname -m)
echo -e "${BLUE}=== [1/4] Architectuur detecteren (${ARCH}) ===${NC}"

# 2. LiveKit Server downloaden en installeren
echo -e "${BLUE}=== [2/4] LiveKit Server downloaden ===${NC}"
if command -v livekit-server &> /dev/null; then
    echo -e "${GREEN}ℹ️ livekit-server is reeds geïnstalleerd: $(livekit-server --version || true)${NC}"
else
    echo "Officiële LiveKit installatiewizard uitvoeren..."
    curl -sSL https://get.livekit.io | bash
fi

if ! command -v livekit-server &> /dev/null; then
    echo -e "${YELLOW}Fallback: Direct binary ophalen van GitHub releases...${NC}"
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        DOWNLOAD_URL="https://github.com/livekit/livekit/releases/latest/download/livekit-server_linux_arm64.tar.gz"
    else
        DOWNLOAD_URL="https://github.com/livekit/livekit/releases/latest/download/livekit-server_linux_armv7.tar.gz"
    fi
    curl -sSL "$DOWNLOAD_URL" -o /tmp/livekit.tar.gz
    tar -xzf /tmp/livekit.tar.gz -C /usr/local/bin/
    chmod +x /usr/local/bin/livekit-server
    rm -f /tmp/livekit.tar.gz
fi

echo -e "${GREEN}✅ livekit-server binary succesvol geïnstalleerd.${NC}"

# 3. LiveKit YAML configuratie aanmaken
echo -e "${BLUE}=== [3/4] Configuratie /etc/livekit.yaml aanmaken ===${NC}"
cat << 'EOF' > /etc/livekit.yaml
port: 7880
bind_addresses:
  - ""
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50100
  use_external_ip: false
keys:
  mycolab_key: mycolab_secret_lab_key_2026
logging:
  level: info
EOF

chmod 644 /etc/livekit.yaml
echo -e "${GREEN}✅ /etc/livekit.yaml geconfigureerd met standaard MycoLab sleutels.${NC}"

# 4. Systemd achtergronddienst inrichten
echo -e "${BLUE}=== [4/4] 24/7 Achtergronddienst (systemd) inrichten ===${NC}"
cat << 'EOF' > /etc/systemd/system/livekit-server.service
[Unit]
Description=LiveKit WebRTC Video Streaming Server for MycoLab
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc
ExecStart=/usr/local/bin/livekit-server --config /etc/livekit.yaml
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable livekit-server.service
systemctl restart livekit-server.service

sleep 2

# Status check
if systemctl is-active --quiet livekit-server.service; then
    PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${BOLD}🎉 GEFELICITEERD! LiveKit Server is actief op je Raspberry Pi!${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "📡 ${BOLD}WebSocket URL voor MycoLab App:${NC} ws://${PI_IP}:7880"
    echo -e "🔑 ${BOLD}API Key:${NC}                        mycolab_key"
    echo -e "🔒 ${BOLD}API Secret:${NC}                     mycolab_secret_lab_key_2026"
    echo -e "⚙️ ${BOLD}Achtergronddienst:${NC}              livekit-server.service (24/7 actief)"
    echo ""
    echo -e "${CYAN}De MycoLab iOS app maakt nu direct verbinding via Wi-Fi met deze server!${NC}"
else
    echo -e "${RED}⚠️ Waarschuwing: service is gestart maar status is nog niet actief.${NC}"
    echo -e "Controleer logs met: ${BOLD}journalctl -u livekit-server.service -e${NC}"
fi
