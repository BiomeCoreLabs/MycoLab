# MycoLabs — App Store Screenshot Playbook & Asset Guide

> **Objective**: An authoritative, high-converting presentation for the App Store that convinces Apple Reviewers and maximizes conversion for cultivators.

---

## 1. Apple Dimensions & Asset Specifications

Apple enforces strict resolution requirements in App Store Connect. The primary required set is the **6.7" / 6.9" display** (iPhone 16 Pro Max / 15 Pro Max):

| Device Type | Pixel Resolution (Portrait) | Xcode Simulator Device | Required? |
| :--- | :--- | :--- | :--- |
| **iPhone 6.7" / 6.9"** | **`1290 x 2796 pixels`** or `1320 x 2868` | iPhone 16 Pro Max / iPhone 15 Pro Max | **Yes (Mandatory)** |
| **iPhone 6.5"** | `1242 x 2688 pixels` | iPhone 11 Pro Max | Recommended |
| **iPad Pro 13"** | `2064 x 2752 pixels` | iPad Pro 13-inch (M4) | Required if iPad active |
| **Mac Catalyst** | `2880 x 1800 pixels` (16:10) | Mac Window | Optional |

> [!TIP]
> **Simulator Screenshot Shortcut**: In the iOS Simulator, press `Cmd + S` to instantly save a pixel-perfect PNG to your Desktop.

---

## 2. The 5 High-Converting App Store Screenshots

Each screenshot combines a clear marketing header with a high-fidelity screen from MycoLabs in **Demo Mode** (ensuring all metrics, curves, and batches display richly populated data).

---

### Screenshot 1: Central Cockpit Dashboard
*First impression in App Store search results.*

- **Marketing Header**: `Complete Grow Control • Live Climate & Batches`
- **View**: `ModernDashboardView`
- **Displayed Elements**:
  - Active batches: *Blue Oyster* (Fruiting 100%) and *Lion's Mane* (Bulk 76%).
  - Telemetry widgets: `21.8°C`, `87.5% RH`, `VPD 0.32 kPa (Optimal)`.
  - Quick action buttons for new batch, manual log, and chamber zones.

---

### Screenshot 2: Live Chamber Camera & 24/7 Monitor
*Appeals to growers needing remote visibility over their chambers.*

- **Marketing Header**: `24/7 Remote Monitoring • Live Video & Timelapse`
- **View**: `LivingGrowCameraCard` & `LiveKitStreamView`
- **Displayed Elements**:
  - Crisp video feed of the fruiting chamber with temperature and humidity overlays.
  - Snapshot buttons for instant sterile inspection and automated interval timelapses.
  - Connection badge: *Live Connected (Ultra-low latency)*.

---

### Screenshot 3: Harvest & Dehydration Calculator
*Highlights culinary yield tracking and professional storage.*

- **Marketing Header**: `Harvest & Supplies • Smart Dehydration Calc`
- **View**: `ModernStashAndStockTabView`
- **Displayed Elements**:
  - Fresh harvest weight logging with automatic dry weight ratio calculation (~10%).
  - QR barcode generation for labeling vacuum bags, mason jars, and liquid cultures.
  - Total yield summary and biological efficiency (BE%) metrics.

---

### Screenshot 4: Hands-Free Cleanroom Voice Assistant
*Demonstrates sterile cleanroom utility while wearing gloves.*

- **Marketing Header**: `Hands-Free Voice AI • Sterile Cleanroom Mode`
- **View**: `CleanroomVoiceConsoleView`
- **Displayed Elements**:
  - Spoken dictation waveform: *"Log harvest 340 grams from Lion's Mane batch"*.
  - Instant on-device neural intent parsing without cloud delays.
  - Visual sterile audio log confirmation.

---

### Screenshot 5: Genetics Lineage & Lab Tools
*Captures advanced cultivators, hobbyists, and laboratory mycologists.*

- **Marketing Header**: `Genetics Lineage • Substrate & Agar Formulas`
- **View**: `ModernGeneticsLabTabView` & `ModernToolsAndPresetsTabView`
- **Displayed Elements**:
  - Multi-generation genetic lineage tree (Spore Print ➔ Liquid Culture ➔ Agar P1/P2 ➔ Grain Spawn).
  - Scalable CVG (Coir, Vermiculite, Gypsum) substrate calculator with exact field-capacity water ratios.
  - Master's Mix and MEA agar media preparation guides.

---

## 3. Post-Production & Frame Assembly

1. Capture clean 1290 x 2796 px screenshots in Xcode Simulator (`Cmd + S`).
2. Add high-contrast typography in the upper safe area.
3. Export as uncompressed 24-bit PNG or high-quality JPEG without alpha transparency.
