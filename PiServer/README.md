# 🍄 MycoLabs Autonomous Pi Hub (24/7 Edge Bridge)

The **MycoLabs Autonomous Pi Hub** turns any Raspberry Pi (e.g. Pi 3B, 4, or 5) into an autonomous microclimate automation and cultivation station for your mushroom laboratory.

The Pi runs 24/7 independently of your iPhone, iPad, or Mac:
* 🔄 **Autonomous Climate Cycles**: Ventilation, humidification, and day/night lighting schedules operate 100% locally via smart Wi-Fi relays.
* 🛡️ **Power-Outage Resilient**: System logs and transient files run in memory (`tmpfs`), the boot partition is hardened against corruption (`read-only`), and swap operates wear-free in `zram`. You can safely unplug power at any moment without filesystem corruption!
* 🌐 **Tailscale Ready**: Secure remote access anywhere in the world from your iPhone or Mac using Tailscale encrypted WireGuard mesh networking.
* 💾 **USB Storage & Backups**: Automated recognition of plugged USB storage drives for growth timelapse video archives and local database snapshots.
* ⏰ **NTP Clock Synchronization**: Even without a hardware RTC coin battery, the Pi immediately synchronizes exact UTC time via NTP as soon as network access is established.

---

## 🚀 Quick Installation (One-Line Command)

Open a terminal (SSH or directly on the Raspberry Pi) and run:

```bash
curl -sSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLabs/main/PiServer/setup.sh | sudo bash
```

### The interactive installation wizard prompts for:
1. 📁 **Installation Path**: Where hub files are deployed (default `~/PiServer`).
2. 🌐 **Tailscale Integration**: Optional encrypted 4G/5G remote access configuration.
3. 🛡️ **Power-Loss Protection**: Enables RAM logging and safeguards SD card endurance.
4. 🔌 **Smart Relays**: Optionally configure smart sockets directly or pair them seamlessly via the MycoLabs iOS app.

---

## 📱 Pairing with the MycoLabs App

1. Open the **MycoLabs** app on your iPhone, iPad, or Mac.
2. Navigate to **Settings ➔ Tuya Smart Hub**.
3. Enter your Raspberry Pi's IP address:
   * **Local Network**: Local LAN IP (e.g. `192.168.1.100` or `pi-lab.local`).
   * **Remote Access**: Your Tailscale node IP (e.g. `100.x.y.z`).
4. Port: `8088`.

---

## 📡 LiveKit WebRTC Video Streaming Server (Port 7880)

To install or update the LiveKit WebRTC streaming server on your Raspberry Pi:

```bash
sudo bash install_livekit.sh
```
or via one-liner:
```bash
curl -sSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLab/main/PiServer/install_livekit.sh | sudo bash
```

* **WebSocket URL for App**: `ws://<PI-IP>:7880` (e.g. `ws://192.168.50.115:7880`)
* **API Key**: `mycolab_key`
* **API Secret**: `mycolab_secret_lab_key_2026`
* **Check LiveKit Service**:
  ```bash
  sudo systemctl status livekit-server.service
  ```

---

## 🛠️ Service Management

* **Browser Status Check**:
  `http://<PI-IP-ADDRESS>:8088/status`
* **Check Service Status**:
  ```bash
  sudo systemctl status mycolab-hub.service
  ```
* **Restart Hub Daemon**:
  ```bash
  sudo systemctl restart mycolab-hub.service
  ```
* **Follow Live Daemon Logs**:
  ```bash
  journalctl -u mycolab-hub.service -f
  ```
