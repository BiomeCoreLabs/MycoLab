#!/usr/bin/env bash
# ==============================================================================
# MycoLab 24/7 Raspberry Pi Hub - Onverwoestbare Installatie, Tailscale & OverlayFS
# ==============================================================================
# Dit script installeert de MycoLab bridge, installeert en activeert Tailscale,
# schakelt swap permanent uit en activeert Read-Only OverlayFS zodat de stekker
# te allen tijde veilig uit het stopcontact getrokken kan worden zonder corruptie.
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Voer dit script uit met sudo:"
  echo "   sudo bash install_hub.sh"
  exit 1
fi

PI_USER="${SUDO_USER:-labadmin4}"
INSTALL_DIR="/home/${PI_USER}/PiServer"

echo "🍄 === [1/7] Systeem updaten en dependencies installeren ==="
apt-get update
apt-get upgrade -y
apt-get install -y python3 python3-pip python3-venv git curl apt-transport-https systemd-timesyncd

echo "🕒 === [2/7] Tijd-synchronisatie (NTP) permanent garanderen ==="
# Zorgt ervoor dat de Pi zodra hij Wi-Fi heeft direct binnen enkele seconden
# de exacte atoomtijd ophaalt, ook al heeft hij geen batterijklokje.
timedatectl set-ntp true
systemctl enable systemd-timesyncd
systemctl restart systemd-timesyncd

echo "🌐 === [3/7] Tailscale installeren ==="
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled
    echo "✅ Tailscale succesvol geïnstalleerd."
else
    echo "ℹ️ Tailscale is al geïnstalleerd."
fi

echo "📁 === [4/7] Bestandsmappen & USB opslaglocatie configureren ==="
mkdir -p "$INSTALL_DIR"
mkdir -p /mnt/pi-storage
chown -R "$PI_USER:$PI_USER" "$INSTALL_DIR"
chown -R "$PI_USER:$PI_USER" /mnt/pi-storage

# USB automount toevoegen aan /etc/fstab indien nog niet aanwezig (nofail zorgt dat hij altijd start, ook zonder stick)
if ! grep -q "/mnt/pi-storage" /etc/fstab; then
    echo "/dev/sda1 /mnt/pi-storage auto defaults,nofail,noatime,users 0 0" >> /etc/fstab
fi

# Python virtuele omgeving opzetten
cd "$INSTALL_DIR"
if [ ! -d "venv" ]; then
    sudo -u "$PI_USER" python3 -m venv venv
fi

sudo -u "$PI_USER" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip
sudo -u "$PI_USER" "$INSTALL_DIR/venv/bin/pip" install fastapi uvicorn tinytuya pydantic requests python-multipart

echo "⚙️ === [5/7] Automatische achtergronddienst (systemd) inrichten ==="
cat << 'EOF' > /etc/systemd/system/mycolab-hub.service
[Unit]
Description=MycoLab 24/7 Autonomous Pi Lab Hub Bridge
After=network-online.target tailscaled.service systemd-timesyncd.service
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/PiServer
ExecStart=/home/pi/PiServer/venv/bin/uvicorn bridge:app --host 0.0.0.0 --port 8088
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Gebruikersnaam en pad dynamisch aanpassen
sed -i "s|User=pi|User=${PI_USER}|g" /etc/systemd/system/mycolab-hub.service
sed -i "s|/home/pi|/home/${PI_USER}|g" /etc/systemd/system/mycolab-hub.service

systemctl daemon-reload
systemctl enable mycolab-hub.service
systemctl restart mycolab-hub.service

echo "🛑 === [6/7] Swap permanent uitschakelen (SD-kaart bescherming) ==="
dphys-swapfile swapoff || true
dphys-swapfile uninstall || true
systemctl disable dphys-swapfile || true

echo ""
echo "🔗 === [Tailscale Inloggen] ==="
echo "We gaan Tailscale nu koppelen vóórdat we de SD-kaart op alleen-lezen zetten."
echo "Klik op onderstaande link zodra deze verschijnt om de Pi te autoriseren in je Tailscale dashboard:"
echo "------------------------------------------------------------------------------"
tailscale up --operator="$PI_USER" || true
echo "------------------------------------------------------------------------------"
echo "✅ Tailscale IP op je netwerk: $(tailscale ip -4 2>/dev/null || echo 'nog niet ingelogd')"
echo ""

echo "🛡️ === [7/7] Read-Only OverlayFS (Stroomuitval-bescherming) activeren ==="
echo "Met OverlayFS worden alle tijdelijke schrijfacties in het RAM-geheugen bewaard."
echo "De fysieke SD-kaart staat 100% op Alleen-Lezen (Read-Only)."
echo "Hierdoor kan de Pi op elk moment stroomloos raken ZONDER corruptie."

raspi-config nonint enable_overlayfs
raspi-config nonint enable_bootro

echo ""
echo "=============================================================================="
echo "✅ ALLES VOLTOOID! De MycoLab Hub + Tailscale is 100% beschermd."
echo "🔄 Herstart de Raspberry Pi om de Read-Only bescherming actief te maken:"
echo "   sudo reboot"
echo "=============================================================================="
