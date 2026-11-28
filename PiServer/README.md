# 🍄 MycoLab Autonomous Pi Hub (24/7 Edge Bridge & Video Streamer)

The **MycoLab Autonomous Pi Hub** turns any Raspberry Pi (Pi 3B, 4, 5, or Zero 2W) into a 24/7 autonomous microclimate automation and high-definition video streaming station for your mushroom laboratory.

The Pi operates completely independently of your iPhone, iPad, or Mac:
* 🔄 **Autonomous Climate Cycles**: Humidity, ventilation, and lighting schedules operate 100% locally via smart Wi-Fi relays (Tuya, Shelly, Tasmota, Home Assistant).
* 📹 **24/7 WebRTC Video Streaming**: LiveKit WebRTC server on port 7880 with background H.264 camera publishing for instant live video and timelapse archives.
* 📷 **Optical Chamber Preview**: Instant HTTP snapshots at `/camera/snapshot` for the iOS lock screen, dynamic island, and home screen widgets.
* 🛡️ **Power-Outage Resilient**: System logs and transient files run in memory (`tmpfs`), the boot partition is hardened against corruption (`read-only`), and swap operates wear-free in `zram`. Safely unplug at any time without data loss!
* 🌐 **ZeroConf mDNS**: Discovered automatically by the MycoLab app under `pi-lab.local:8088`—no need to manually type IP addresses!
* 📶 **Tailscale Ready**: Encrypted WireGuard remote access anywhere in the world over 4G/5G.
* 💾 **USB Storage & Backups**: Automated recognition of plugged USB drives for timelapse archives and local SQLite database backups.

---

## 🚀 Quick Installation (One-Line Terminal Command)

Log in to your Raspberry Pi via SSH or open the terminal, then run:

```bash
curl -sSL https://raw.githubusercontent.com/BiomeCoreLabs/MycoLab/main/PiServer/setup.sh | sudo bash
```

### The interactive installer configures:
1. 📂 **Deployment Path**: Sets up the virtual environment in `~/PiServer`.
2. 🌐 **ZeroConf mDNS**: Publishes `pi-lab.local` so iOS devices detect it automatically.
3. 📡 **LiveKit WebRTC Server & Camera Publisher**: Configures `livekit-server.service` and `mycolab-camera.service`.
4. 🛡️ **SD-Card Lifespan & Power-Failure Shield**: Relocates volatile logging to RAM.
5. 📱 **Instant Pairing QR Code**: Prints an ANSI pairing QR code in the terminal to scan with the MycoLab app!

---

## 📱 Pairing with the MycoLab App

You can pair your Pi Hub in three effortless ways:

1. **Auto-Discovery (1-Tap)**:
   - In the MycoLab app (or during the initial Onboarding Wizard), tap **"🔍 Zoek in Wi-Fi"**.
   - The app detects `pi-lab.local:8088` within one second.
2. **QR Code Pairing**:
   - In the app, tap **"📷 Scan QR"**.
   - Point your camera at the QR code displayed in the Pi terminal after running `setup.sh`.
3. **Manual or Tailscale**:
   - Navigate to **Settings ➔ Tuya Smart Hub**.
   - Enter `pi-lab.local` (local Wi-Fi) or your 100.x.y.z Tailscale IP (remote 4G/5G).
   - Port: `8088`.

---

## 📹 LiveKit WebRTC Camera Publisher (Port 7880)

* **Server Port**: `7880` (WebRTC signaling) & `7881` (TCP fallback)
* **Default Room**: `mycolab-grow-room`
* **Default Identity**: `pi-cam`
* **API Key**: `mycolab_key`
* **API Secret**: `mycolab_secret_lab_key_2026`
* **Direct Snapshot URL**: `http://pi-lab.local:8088/camera/snapshot`
* **Camera Status API**: `http://pi-lab.local:8088/camera/status`

### Check Services:
```bash
sudo systemctl status mycolab-hub.service       # FastAPI & Automation Bridge
sudo systemctl status livekit-server.service    # WebRTC Video Streaming Server
sudo systemctl status mycolab-camera.service    # H.264 Camera Publisher
```

---

## 💻 Native macOS Application

Download the universal Apple Silicon & Intel macOS DMG installer directly from:
* [MycoLab-macOS.dmg](https://biomecorelabs.github.io/MycoLab/MycoLab-macOS.dmg)
