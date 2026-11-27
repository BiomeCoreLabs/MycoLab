# MycoLabs ⌁
### The Open, Modular & Universal Smart Mycology Suite
**Architected by [BiomeCore Labs](https://biomecorelabs.github.io/MycoLabs)**

[![Platform](https://img.shields.io/badge/Platform-iOS%2017.6+%20%7C%20iPadOS%20%7C%20macOS-00FFAA?style=for-the-badge&logo=apple&logoColor=black)](https://github.com/BiomeCoreLabs/MycoLabs)
[![Language](https://img.shields.io/badge/Language-Swift%206.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://github.com/BiomeCoreLabs/MycoLabs)
[![Architecture](https://img.shields.io/badge/Architecture-100%25%20Local--First-00E5FF?style=for-the-badge&logo=icloud&logoColor=black)](https://github.com/BiomeCoreLabs/MycoLabs)
[![Hardware](https://img.shields.io/badge/Hardware-Universal%20%26%20Modular-FF9100?style=for-the-badge)](https://github.com/BiomeCoreLabs/MycoLabs)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry%20%7C%20No%20Tracking-00E676?style=for-the-badge)](https://github.com/BiomeCoreLabs/MycoLabs)
[![Interactive Web Demo](https://img.shields.io/badge/Web%20Simulator-Test%20Online-9D4EDD?style=for-the-badge)](https://biomecorelabs.github.io/MycoLabs)

---

## 🌐 Test the App Directly in Your Browser
Want to try MycoLabs without installing anything?  
👉 **[Launch the Interactive Web Simulator](https://biomecorelabs.github.io/MycoLabs)** to test real-time climate telemetry, dynamic VPD calculations, the genetics lineage tree, and hands-free voice controls right in your browser.

---

## 💡 The Philosophy: Freedom, Modularity & Total Choice

Most cultivation software forces you into proprietary ecosystems—expensive vendor-locked sensors, mandatory cloud subscriptions, or rigid tent configurations.

**MycoLabs breaks the mold:**
* 🎯 **Choose Your Cultivation Method:** Whether you cultivate in simple monotubs, shoeboxes, automated Martha tents, agar cleanrooms, fruiting bags on shelves, or walk-in chambers—MycoLabs adapts to your workflow.
* 🔌 **Hardware Agnostic (or 100% Hardware-Free):**
  * Connect smart plugs and environmental probes over your local network using Tuya LAN, MQTT, Home Assistant, ESP32, or Raspberry Pi.
  * No smart hardware? Use MycoLabs as a **100% manual digital lab notebook** with precision calculators, timers, and lineage tracking.
* 🧬 **Full Control Over Genetics & Recipes:** Define your own custom strains, species, fruiting temperatures, colonization setpoints, agar formulas, and substrate recipes.
* 🛡️ **100% Local-First & Privacy-Focused:** No mandatory accounts, zero data transmission to external servers, no ads, and no tracking. Everything stays securely on your Apple device.

---

## 🔬 Core Capabilities

### 1. 🎛️ Dynamic Climate & VPD Autopilot Engine
* **Real-time Vapor Pressure Deficit (VPD):** Computes mushroom transpiration rates using thermodynamic psychrometric formulas (Tetens and Arden Buck equations) based on ambient temperature and relative humidity (% RH).
* **Customizable Target Ranges:** Configure your own target microclimates for colonization, pinning triggers, and fruiting phases.
* **Condensation Interlock:** Smart alerts warn against water oversaturation and blotch risks on delicate mushroom caps.

### 2. 🧬 Genetics Vault & Lineage Tree Explorer
* **Generation Tracking:** Organize Spore Prints, Spore Syringes, Liquid Cultures (LC), Agar Isolates (P1, P2, P3...), and Grain Masters.
* **Interactive Lineage Tree:** Trace any isolate's complete ancestral path back to its parent spore or tissue clone.
* **Viability & Expiry Timers:** Timely notifications before refrigerated agar slants or liquid cultures lose vitality.

### 3. 🎙️ Cleanroom Hands-Free Voice Console
* **Sterile Glove Operation:** Operate your lab without touching screens in front of laminar flow hoods or still air boxes (SAB).
* **Local Offline Voice Intent Recognition:** Speak natural commands such as:
  * *"Start 15-minute mist cycle"*
  * *"Log harvest 340 grams"*
  * *"What is the current VPD?"*
  * *"Capture grow camera snapshot"*

### 4. 🧮 Laboratory Calculators
* **CVG Substrate Scaler:** Calculate dry weights of Coco Coir, Coarse Vermiculite, and Gypsum ($CaSO_4$) along with boiling water volumes for optimal field capacity.
* **Master's Mix Calculator:** Scalable 50/50 formulas for hardwood sawdust and soybean hulls.
* **Agar Recipe Scaler:** Precision gram measurements for Malt Extract Agar (MEA), Potato Dextrose Yeast Agar (PDYA), and water agar.
* **Dehydration & Biological Efficiency (BE%):** Instantly compute moisture loss and biological yield ratios from fresh harvest and dry grain weight.

### 5. 📹 24/7 WebRTC Chamber Camera & Timelapse
* **Sub-Second Latency:** Connect any iPhone, iPad, or Mac as a dedicated chamber camera node via LiveKit WebRTC.
* **Automated Timelapse Engine:** Capture scheduled high-resolution growth frames across multi-day flushes and export directly to your Photos library.

### 6. 📱 iOS 17+, iPadOS & macOS Integration
* **Live Activities & Dynamic Island:** Monitor live microclimates and active timers directly from the Lock Screen.
* **Universal Layout:** Responsive 2-column sidebar navigation on Mac Catalyst and iPad Pro with hardware keyboard shortcuts (`⌘1` through `⌘4`).

---

## 🛠️ Build & Run from Source with Xcode

MycoLabs is a native Swift application built for Apple platforms:

```bash
# 1. Clone the repository
git clone https://github.com/BiomeCoreLabs/MycoLabs.git
cd MycoLabs

# 2. Open project in Xcode
open MycoLabs.xcodeproj
```

* **Simulator:** Select `MycoLabs` > any iOS Simulator (e.g. iPhone 16/17/18 Pro) and press `⌘ + R`.
* **Physical Device:** Select your own Apple ID under *Signing & Capabilities* to install locally without committing personal credentials.

---

## 🔒 Security & Privacy

* No telemetry, no third-party tracking libraries, and no hidden analytics.
* No account registration or external cloud server requirement.
* Optional biometric authentication (Face ID / Touch ID) with an integrated Decoy Vault mode to safeguard proprietary strain databases.

---

## 📄 Documentation & Links

* **Interactive Web Simulator:** [biomecorelabs.github.io/MycoLabs](https://biomecorelabs.github.io/MycoLabs)
* **Helpdesk & Guides:** [Support Center](https://biomecorelabs.github.io/MycoLabs/support.html)
* **Privacy Disclosures:** [Privacy Policy](https://biomecorelabs.github.io/MycoLabs/privacy_policy.html)
