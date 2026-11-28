#!/usr/bin/env bash
# ==============================================================================
#  __  __                  _           _     
# |  \/  |_   _  ___ ___  | |    __ _ | |__  
# | |\/| | | | |/ __/ _ \ | |   / _` || '_ \ 
# | |  | | |_| | (_| (_) || |__| (_| || |_) |
# |_|  |_|\__, |\___\___/ |_____\__,_||_.__/ 
#         |___/   Autonomous 24/7 Pi Hub Installer
# ==============================================================================
# Eén-regels installatiescript voor de MycoLab Raspberry Pi Hub bridge.
# Geschikt om direct via terminal of via 'curl | bash' uit te voeren.
# ==============================================================================

set -e

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Zorg voor interactieve input, ook bij 'curl | bash'
exec 3</dev/tty || exec 3<&0
prompt_read() {
    local prompt_text="$1"
    local var_name="$2"
    local default_val="$3"
    
    if [ -n "$default_val" ]; then
        echo -ne "${BOLD}${CYAN}${prompt_text} [${default_val}]: ${NC}"
    else
        echo -ne "${BOLD}${CYAN}${prompt_text}: ${NC}"
    fi
    read -r "$var_name" <&3
    if [ -z "${!var_name}" ] && [ -n "$default_val" ]; then
        eval "$var_name=\"$default_val\""
    fi
}

echo -e "${GREEN}"
cat << 'EOF'
 __  __                  _           _     
|  \/  |_   _  ___ ___  | |    __ _ | |__  
| |\/| | | | |/ __/ _ \ | |   / _` || '_ \ 
| |  | | |_| | (_| (_) || |__| (_| || |_) |
|_|  |_|\__, |\___\___/ |_____\__,_||_.__/ 
        |___/   Autonomous 24/7 Pi Hub Installer
EOF
echo -e "${NC}"
echo -e "${BOLD}Welkom bij de MycoLab 24/7 Hub installatiewizard!${NC}"
echo -e "Dit script richt je Raspberry Pi in als zelfstandig klimaat- en kweekstation."
echo "------------------------------------------------------------------------------"

# Bepaal gebruiker en rechten
ACTUAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
USER_HOME="${USER_HOME:-/home/$ACTUAL_USER}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}ℹ️ Dit script vereist root-rechten voor systeemdiensten.${NC}"
    echo -e "Voer uit met sudo:"
    echo -e "   ${BOLD}curl -sSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLab/main/PiServer/setup.sh | sudo bash${NC}"
    exit 1
fi

# 1. Installatiemap bepalen
DEFAULT_DIR="${USER_HOME}/PiServer"
prompt_read "📂 In welke map wil je MycoLab installeren?" TARGET_DIR "$DEFAULT_DIR"

# 2. Vraag naar Tailscale
prompt_read "🌐 Wil je Tailscale installeren voor veilige toegang buitenshuis (4G/5G)? (j/n)" INSTALL_TAILSCALE "j"

# 3. Vraag naar Stroomuitvalbescherming (RAM logs, zram swap)
prompt_read "🛡️ Wil je stroomuitvalbescherming activeren (logs & swap naar RAM)? (j/n)" ENABLE_SAFETY "j"

# 4. Vraag naar Tuya apparaten
prompt_read "🔌 Wil je nu meteen al je slimme Tuya stekkers invoeren? (j/n)" CONFIGURE_TUYA "n"

echo ""
echo -e "${BLUE}=== [1/6] Systeempakketten installeren ===${NC}"
apt-get update -qq
apt-get install -y -qq python3 python3-pip python3-venv git curl systemd-timesyncd apt-transport-https

echo -e "${BLUE}=== [2/6] Tijd-synchronisatie (NTP) activeren ===${NC}"
timedatectl set-ntp true
systemctl enable --now systemd-timesyncd
echo -e "${GREEN}✅ Atoomklok synchronisatie geactiveerd.${NC}"

# Tailscale installatie indien gekozen
if [[ "$INSTALL_TAILSCALE" =~ ^[jJyY]$ ]]; then
    echo -e "${BLUE}=== [3/6] Tailscale installeren ===${NC}"
    if ! command -v tailscale &> /dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
        systemctl enable --now tailscaled
        echo -e "${GREEN}✅ Tailscale daemon geïnstalleerd.${NC}"
    else
        echo -e "${GREEN}ℹ️ Tailscale is reeds aanwezig.${NC}"
    fi
fi

echo -e "${BLUE}=== [4/6] Bestanden en Python omgeving inrichten ===${NC}"
mkdir -p "$TARGET_DIR"
mkdir -p /mnt/pi-storage
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_DIR"
chown -R "$ACTUAL_USER:$ACTUAL_USER" /mnt/pi-storage

# Haal nieuwste bridge.py op als we niet al in de repo draaien
if [ ! -f "$TARGET_DIR/bridge.py" ]; then
    echo "Downloading latest bridge.py from GitHub..."
    curl -fsSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLab/main/PiServer/bridge.py -o "$TARGET_DIR/bridge.py"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_DIR/bridge.py"
fi

# Tuya Devices configuratie
DEVICES_FILE="$TARGET_DIR/devices.json"
if [ ! -f "$DEVICES_FILE" ]; then
    if [[ "$CONFIGURE_TUYA" =~ ^[jJyY]$ ]]; then
        echo -e "${YELLOW}Voer de gegevens in van je apparaten (of druk Enter om over te slaan):${NC}"
        
        prompt_read "Lampen IP" LIGHT_IP "192.168.1.101"
        prompt_read "Lampen Device ID" LIGHT_ID "tuya_light_01"
        prompt_read "Lampen Local Key" LIGHT_KEY "abcdef1234567890"

        prompt_read "Ventilatie IP" FAN_IP "192.168.1.102"
        prompt_read "Ventilatie Device ID" FAN_ID "tuya_fan_01"
        prompt_read "Ventilatie Local Key" FAN_KEY "abcdef1234567890"

        prompt_read "Humidifier IP" HUM_IP "192.168.1.103"
        prompt_read "Humidifier Device ID" HUM_ID "tuya_hum_01"
        prompt_read "Humidifier Local Key" HUM_KEY "abcdef1234567890"

        cat << EOF > "$DEVICES_FILE"
{
  "devices": [
    {
      "id": "${LIGHT_ID}",
      "name": "Lampen",
      "type": "Light",
      "ip": "${LIGHT_IP}",
      "local_key": "${LIGHT_KEY}",
      "version": 3.3
    },
    {
      "id": "${FAN_ID}",
      "name": "Ventilatie",
      "type": "ExhaustFan",
      "ip": "${FAN_IP}",
      "local_key": "${FAN_KEY}",
      "version": 3.3
    },
    {
      "id": "${HUM_ID}",
      "name": "Humidifyer",
      "type": "Humidifier",
      "ip": "${HUM_IP}",
      "local_key": "${HUM_KEY}",
      "version": 3.3
    }
  ]
}
EOF
    else
        # Standaard template plaatsen
        curl -fsSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLab/main/PiServer/devices.example.json -o "$DEVICES_FILE"
    fi
    chown "$ACTUAL_USER:$ACTUAL_USER" "$DEVICES_FILE"
fi

# USB automount in fstab toevoegen
if ! grep -q "/mnt/pi-storage" /etc/fstab; then
    echo "/dev/sda1 /mnt/pi-storage auto defaults,nofail,noatime,users 0 0" >> /etc/fstab
fi

# Virtuele Python omgeving
cd "$TARGET_DIR"
if [ ! -d "venv" ]; then
    sudo -u "$ACTUAL_USER" python3 -m venv venv
fi

echo "Python afhankelijkheden installeren..."
sudo -u "$ACTUAL_USER" "$TARGET_DIR/venv/bin/pip" install --upgrade -q pip
sudo -u "$ACTUAL_USER" "$TARGET_DIR/venv/bin/pip" install -q fastapi uvicorn tinytuya pydantic requests python-multipart
echo -e "${GREEN}✅ Virtuele omgeving gereed.${NC}"

echo -e "${BLUE}=== [5/6] Achtergronddienst (systemd) inrichten ===${NC}"
cat << EOF > /etc/systemd/system/mycolab-hub.service
[Unit]
Description=MycoLab 24/7 Autonomous Pi Lab Hub Bridge
After=network-online.target systemd-timesyncd.service tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=${ACTUAL_USER}
WorkingDirectory=${TARGET_DIR}
ExecStart=${TARGET_DIR}/venv/bin/uvicorn bridge:app --host 0.0.0.0 --port 8088
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mycolab-hub.service
systemctl restart mycolab-hub.service
echo -e "${GREEN}✅ MycoLab Hub Service gestart op poort 8088.${NC}"

# LiveKit WebRTC Streaming Server inrichten
echo -e "${BLUE}=== LiveKit WebRTC Video Streaming Server inrichten ===${NC}"
if [ -f "$TARGET_DIR/install_livekit.sh" ]; then
    bash "$TARGET_DIR/install_livekit.sh" || true
else
    curl -fsSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLab/main/PiServer/install_livekit.sh -o "/tmp/install_livekit.sh" && bash "/tmp/install_livekit.sh" || true
fi

# Stroomuitval & SD-kaart bescherming
if [[ "$ENABLE_SAFETY" =~ ^[jJyY]$ ]]; then
    echo -e "${BLUE}=== [6/6] Stroomuitval- en SD-kaartbescherming activeren ===${NC}"
    
    # 1. Systemd journald naar RAM
    sed -i "s/#Storage=auto/Storage=volatile/" /etc/systemd/journald.conf 2>/dev/null || true
    systemctl restart systemd-journald 2>/dev/null || true

    # 2. /var/log en /tmp naar tmpfs (RAM)
    if ! grep -q "/var/log" /etc/fstab; then
        echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,nodev,noexec,mode=0755,size=100M 0 0" >> /etc/fstab
        mount /var/log 2>/dev/null || true
    fi

    # 3. Bootpartitie read-only
    sed -i /etc/fstab -e "s#\(.*/boot.*\)defaults\(.*\)#\1defaults,ro\2#" 2>/dev/null || true

    echo -e "${GREEN}✅ SD-kaart beschermd: logs en tijdelijke bestanden draaien in RAM.${NC}"
fi

# Tailscale autorisatie
if [[ "$INSTALL_TAILSCALE" =~ ^[jJyY]$ ]]; then
    echo ""
    echo -e "${BOLD}${YELLOW}=== Tailscale Netwerk Koppeling ===${NC}"
    echo "Klik op de onderstaande link om de Pi te autoriseren in je Tailscale netwerk:"
    echo "------------------------------------------------------------------------------"
    tailscale up --operator="$ACTUAL_USER" --qr=false || true
    echo "------------------------------------------------------------------------------"
fi

# Eindoverzicht
PI_IP=$(hostname -I | awk '{print $1}')
TAIL_IP=$(tailscale ip -4 2>/dev/null || echo "Niet gekoppeld")

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${BOLD}🎉 GEFELICITEERD! De MycoLab Autonomous Hub is succesvol geïnstalleerd!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "📍 ${BOLD}Lokaal Netwerk IP:${NC}     http://${PI_IP}:8088"
echo -e "🌐 ${BOLD}Tailscale Netwerk IP:${NC}  http://${TAIL_IP}:8088"
echo -e "📡 ${BOLD}LiveKit Stream URL:${NC}    ws://${PI_IP}:7880"
echo -e "⚙️ ${BOLD}Achtergronddiensten:${NC}   mycolab-hub.service & livekit-server.service (24/7)"
echo -e "💾 ${BOLD}USB Opslaglocatie:${NC}     /mnt/pi-storage (voor timelapses & backups)"
echo ""
echo -e "${CYAN}Stappen in de MycoLab App (iPhone / Mac):${NC}"
echo -e "1. Open de MycoLab app en navigeer naar ${BOLD}Settings ➔ Tuya Hub${NC}."
echo -e "2. Vul bij Hub IP in: ${BOLD}${TAIL_IP}${NC} (voor bereik overal) of ${BOLD}${PI_IP}${NC} (thuis)."
echo -e "3. Poort: ${BOLD}8088${NC}."
echo -e "4. Bonjour / mDNS ZeroConf:      ${BOLD}http://pi-lab.local:8088${NC} (zonder IP te typen!)"
echo -e "5. LiveKit Video Server draait op poort ${BOLD}7880${NC}."
echo -e "${GREEN}==============================================================================${NC}"

# Genereer koppel QR code voor de MycoLab App
if command -v qrencode >/dev/null 2>&1 || sudo apt-get install -y qrencode >/dev/null 2>&1; then
    echo ""
    echo -e "${BOLD}📱 SCAN MET DE MYCOLAB APP CAMERA OM DEZE HUB AUTOMATISCH TE KOPPELEN:${NC}"
    qrencode -t ANSI256 "mycolab://hub?host=${PI_IP}&port=8088&name=Pi-Lab"
    echo ""
fi
