# DEVELOPER AI AGENT HANDBOOK & KNOWLEDGE BASE
**App Name:** MycoLabs  
**Studio / Developer:** BiomeCore Labs  
**App Type:** Professional Laboratory, Climate & Cultivation Management System for Culinary & Medicinal Mushrooms  
**Target Platform:** iOS 17.6+ (iPhone & iPad), macOS Catalyst  
**Official Bundle ID:** `com.mycolab.app`  
**App Group ID:** `group.com.mycolab.app`  
**Background Autopilot ID:** `com.mycolab.autopilot`  
**Status:** 100% Production-Ready for App Store Review (Archive Succeeded, 30+ Tests Green)  

---

## 1. MISSION & IDENTITY (For Any New AI Assistant)
As an AI Developer Assistant for MycoLabs, you work on a **high-caliber, privacy-sovereign laboratory application** for the controlled cultivation of edible gourmet mushrooms (e.g. Oyster mushrooms, Shiitake) and functional medicinal species (such as Lion's Mane and Reishi).

### Strict Core Guidelines:
1. **Apple Guideline 1.4.3 (Zero Tolerance on Prohibited Substances):**
   - Never add or suggest illegal, psychedelic, or psilocybin-related species.
   - Prohibited terms in code, UI, or documentation: *Psilocybe*, *cubensis*, *natalensis*, *APE*, *Golden Teacher*, *Microdosing*.
   - Permitted species: *Pleurotus ostreatus (Blue Oyster)*, *Hericium erinaceus (Lion's Mane)*, *Lentinula edodes (Shiitake)*, *Pleurotus eryngii (King Oyster)*, *Ganoderma lucidum (Reishi)*.
2. **Apple Guideline 2.5.4 & Background Tasks:**
   - No artificial audio keep-alive loops.
   - Background telemetry and climate monitoring utilize Apple's official `BGTaskScheduler` (`fetch` and `processing`).
3. **Privacy-First (Local-First Architecture):**
   - All cultivation data, photographs, and notes remain 100% local on the device.
   - Zero tracking SDKs, zero IDFA, no mandatory accounts.
   - The optional setting (`isAnonymousAnalyticsAllowed`) shares only anonymized crash diagnostics to improve stability.

---

## 2. TECHNICAL ARCHITECTURE

### Core Frameworks & Dependencies
- **SwiftUI + Combine**: Fully reactive UI with dark-mode laboratory aesthetic (`MycoTheme`).
- **LiveKit WebRTC (`LiveKitUniFFI`)**: Low-latency peer-to-peer video streaming for 24/7 chamber monitoring.
- **Tuya IoT API & LAN Engine**: Direct local Wi-Fi communication and fallback cloud controls for ultrasonic humidifiers, FAE exhaust fans, and grow LEDs.
- **Local Authentication (Biometrics)**: Face ID / Touch ID protection with secondary Decoy Vault profile (`MycoDecoyVaultManager`).
- **WidgetKit**: Lock Screen and Home Screen widgets via shared container `group.com.mycolab.app`.

### Key Files & Responsibilities
| File | Responsibility |
| :--- | :--- |
| `MycoStore.swift` | Central data store (`AppDatabase`), JSON persistence, demo seeder, and climate orchestration. |
| `MycoModels.swift` | Primary data models (`GrowProject`, `StrainModel`, `SmartDeviceItem`, `SupplyItem`). |
| `ModernDashboardView.swift` | Main screen featuring live telemetry, active batches, and quick action dock. |
| `ModernGeneticsLabTabView.swift` | Culture lineage tree, spore print tracking, liquid cultures, and agar transfers. |
| `ModernStashAndStockTabView.swift` | Harvest records, inventory jars, dehydration ratios, and laboratory supplies. |
| `ModernToolsAndPresetsTabView.swift` | Substrate calculators (CVG / Master's Mix) and Culinary Yield ratios. |
| `CleanroomVoiceConsoleView.swift` | Hands-free cleanroom voice dictation for sterile glove operations. |
| `LivingGrowCameraCard.swift` | Live chamber viewport with interval timelapse and snapshot export. |
| `MycoBackgroundHubManager.swift` | Registration and dispatch of `BGTaskScheduler` background tasks. |
| `PrivacyInfo.xcprivacy` | Apple Privacy Manifest with declared API reasons (CA92.1, C617.1, 35F9.1). |

---

## 3. REVIEWER & DEMO ENVIRONMENT (Apple Guideline 2.1)
- To prevent hardware-dependency rejections during App Store review, MycoLabs provides a **Demo Mode**:
  - Activated via onboarding wizard (`AIOnboardingWizardView`) or launch argument `-demoMode`.
  - Populates 3 culinary strains, 2 realistic cultivation batches (Fruiting and Bulk phases), and virtual telemetry.
  - Displays an amber exit banner on the dashboard to clear demo data with a single tap.
