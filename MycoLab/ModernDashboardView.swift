//
//  ModernDashboardView.swift
//  MycoLab
//
//  Modern Living Lab Dashboard:
//  - Serene Apple-grade layout with spacious visual hierarchy
//  - Living bio-visuals: breathing colonization rings, ambient telemetry & radar waves
//  - Compact hardware strip for grow cameras & Tuya sensors
//  - 100% reversible: can switch to Classic Lab at any moment
//

import SwiftUI
import Combine

// MARK: - LIVING COLONIZATION RING COMPONENT
struct LivingColonizationRing: View {
    let progress: Double // 0.0 ... 100.0
    let phase: GrowPhase
    let daysActive: Int
    
    @State private var isPulsing = false
    @State private var waveScale: CGFloat = 1.0
    @State private var waveOpacity: Double = 0.8
    
    private var normalizedProgress: Double {
        if progress > 0.0 && progress <= 1.0 {
            return progress
        }
        return max(0.0, min(1.0, progress / 100.0))
    }
    
    private var displayPercent: Int {
        if progress > 0.0 && progress <= 1.0 {
            return Int(round(progress * 100.0))
        }
        return Int(round(min(max(progress, 0.0), 100.0)))
    }
    
    var body: some View {
        ZStack {
            // Radiating bio-wave ripple
            Circle()
                .stroke(phase.color.opacity(0.5), lineWidth: 1.5)
                .frame(width: 54, height: 54)
                .scaleEffect(waveScale)
                .opacity(waveOpacity)
            
            // Ambient Bio-Glow behind the ring
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            phase.color.opacity(isPulsing ? 0.45 : 0.15),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 4,
                        endRadius: isPulsing ? 38 : 22
                    )
                )
                .frame(width: 70, height: 70)
                .scaleEffect(isPulsing ? 1.12 : 0.94)
            
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)
                .frame(width: 54, height: 54)
            
            // Progress arc with gradient
            Circle()
                .trim(from: 0.0, to: CGFloat(normalizedProgress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            phase.color.opacity(0.7),
                            phase.color,
                            phase.color.opacity(0.9)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 54, height: 54)
            
            // Center content: Days active or percentage
            VStack(spacing: 0) {
                Text("\(displayPercent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("D\(daysActive)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(MycoTheme.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                waveScale = 1.45
                waveOpacity = 0.0
            }
        }
    }
}

// MARK: - MODERN BOUNCY BUTTON STYLE
struct ModernBouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - LAB CLIMATE & TELEMETRY HERO CARD
struct LivingLabBioHeroCard: View {
    @EnvironmentObject var store: MycoStore
    let activeBatches: Int
    var onLogManualClimate: () -> Void = {}
    
    @State private var isBreathing = false
    
    private var hasActiveSensor: Bool {
        store.db.environmentConfig.hasActiveSensor
    }
    
    private var isManualReading: Bool {
        store.db.environmentConfig.isManualReading
    }
    
    private var currentTemp: Double? {
        store.db.environmentConfig.currentTempC
    }
    
    private var currentHumidity: Double? {
        store.db.environmentConfig.currentHumidityPct
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Compact Title & Action
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(hasActiveSensor ? MycoTheme.green.opacity(0.18) : (isManualReading ? MycoTheme.blue.opacity(0.18) : Color.white.opacity(0.08)))
                            .frame(width: 28, height: 28)
                        Image(systemName: hasActiveSensor ? "sensor.fill" : (isManualReading ? "pencil.circle.fill" : "thermometer.medium"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(hasActiveSensor ? MycoTheme.green : (isManualReading ? MycoTheme.blue : MycoTheme.textSecondary))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Kweektent Klimaat", en: "Grow Tent Climate"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(hasActiveSensor ? MycoTheme.green : (isManualReading ? MycoTheme.blue : MycoTheme.textSecondary))
                                .frame(width: 5, height: 5)
                            Text(hasActiveSensor
                                 ? store.t(nl: "Sensor Actief", en: "Sensor Active")
                                 : (isManualReading
                                    ? store.t(nl: "Handmatige Meting", en: "Manual Reading")
                                    : store.t(nl: "Geen Sensordata", en: "No Sensor Data")))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(hasActiveSensor ? MycoTheme.green : (isManualReading ? MycoTheme.blue : MycoTheme.textSecondary))
                        }
                    }
                }
                
                Spacer()
                
                // Unified Meting knop
                Button {
                    onLogManualClimate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(store.t(nl: "Meting", en: "Log"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(MycoTheme.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MycoTheme.blue.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(MycoTheme.blue.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(ModernBouncyButtonStyle())
            }
            
            // Primary Metrics Row (Compact side-by-side)
            HStack(spacing: 8) {
                // Temperature Tile
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(currentTemp != nil ? MycoTheme.amber : MycoTheme.textSecondary.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Temperatuur", en: "Temperature"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(MycoTheme.textSecondary)
                        
                        if let t = currentTemp {
                            Text(String(format: "%.1f°C", t))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: t)
                        } else {
                            Text("--.-°C")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary.opacity(0.5))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                // Humidity Tile
                HStack(spacing: 8) {
                    Image(systemName: "humidity.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(currentHumidity != nil ? MycoTheme.blue : MycoTheme.textSecondary.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Vochtgehalte", en: "Humidity"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(MycoTheme.textSecondary)
                        
                        if let h = currentHumidity {
                            Text(String(format: "%.0f%% RV", h))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: h)
                        } else {
                            Text("--% RV")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(MycoTheme.textSecondary.opacity(0.5))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            
            // Psychrometric VPD & Dew Point Analysis
            let chamberType = store.db.environmentConfig.growChamberType == "monotub" ? "growTent" : store.db.environmentConfig.growChamberType
            if let vpdAnalysis = MycoVPDCalculator.analyze(tempC: currentTemp, humidityPct: currentHumidity, environment: chamberType) {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: vpdAnalysis.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(vpdAnalysis.color)
                        Text(String(format: "VPD %.2f kPa", vpdAnalysis.vpdKPa))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("•")
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(store.isEnglish ? vpdAnalysis.titleEN : vpdAnalysis.titleNL)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(vpdAnalysis.color)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(vpdAnalysis.color.opacity(0.12))
                    .cornerRadius(5)
                    
                    Spacer()
                    
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.snowflake")
                            .font(.system(size: 9))
                            .foregroundColor(Color.cyan)
                        Text(String(format: "Dauwpunt %.1f°C", vpdAnalysis.dewPointC))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    InfoTipButton(
                        title: store.t(nl: "VPD & Dauwpunt Kennis", en: "VPD & Dew Point Science"),
                        message: store.isEnglish ? vpdAnalysis.detailedAdviceEN : vpdAnalysis.detailedAdviceNL
                    )
                }
            }
            
            // Subtitle & Status Details
            HStack(spacing: 6) {
                if hasActiveSensor {
                    let sensorName = store.db.environmentConfig.sensorDeviceName ?? "Tuya Sensor"
                    let timeStr = store.db.environmentConfig.latestSensorReadingTime?.formatted(date: .omitted, time: .shortened) ?? ""
                    Text(store.t(nl: "Live: \(sensorName) • \(timeStr)", en: "Live: \(sensorName) • \(timeStr)"))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.textSecondary)
                } else if isManualReading, let time = store.db.environmentConfig.manualReadingTime {
                    let timeStr = time.formatted(date: .abbreviated, time: .shortened)
                    Text(store.t(nl: "Handmatig ingevoerd (\(timeStr))", en: "Manually entered (\(timeStr))"))
                        .font(.system(size: 10))
                        .foregroundColor(MycoTheme.blue)
                } else {
                    HStack(spacing: 4) {
                        Text(store.t(nl: "Geen actieve sensor", en: "No active sensor"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary.opacity(0.8))
                        InfoTipButton(
                            title: store.t(nl: "Klimaat Sensor", en: "Climate Sensor"),
                            message: store.t(nl: "Er is momenteel geen actieve sensor gekoppeld. Voeg handmatig metingen toe via de knop Meting of koppel een Tuya sensor.", en: "No active sensor linked. Manually enter readings or pair a Tuya sensor.")
                        )
                    }
                }
                
                Spacer()
                
                if activeBatches > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(MycoTheme.green)
                            .frame(width: 4, height: 4)
                        Text("\(activeBatches) " + store.t(nl: activeBatches == 1 ? "batch" : "batches", en: activeBatches == 1 ? "batch" : "batches"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(MycoTheme.green)
                    }
                } else {
                    Text(store.t(nl: "Geen batches", en: "No batches"))
                        .font(.system(size: 9))
                        .foregroundColor(MycoTheme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(
            ZStack {
                MycoTheme.card
                LinearGradient(
                    colors: [
                        (hasActiveSensor ? MycoTheme.green : (isManualReading ? MycoTheme.blue : Color.white.opacity(0.1))).opacity(isBreathing ? 0.08 : 0.03),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    (hasActiveSensor ? MycoTheme.green : (isManualReading ? MycoTheme.blue : MycoTheme.border))
                        .opacity(isBreathing ? 0.35 : 0.18),
                    lineWidth: 1
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

// MARK: - CLIMATE MEASUREMENT & OPTICAL SENSOR STUDIO SHEET
struct ClimateMeasurementStudioSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var opticalManager = MycoOpticalHygrometerManager.shared
    
    @State private var inputMode: Int = 0 // 0 = Optische Sensor (AI), 1 = Handmatige Invoer
    
    // Values
    @State private var tempText: String = "22.0"
    @State private var humidityText: String = "85"
    @State private var measurementDate: Date = Date()
    @State private var notes: String = ""
    
    // Optical Scan State
    @State private var isScanning: Bool = false
    @State private var previewImage: UIImage? = nil
    @State private var recognizedConfidence: Double? = nil
    @State private var scanStatusMessage: String = ""
    
    // Sub-sheets for zones & full menu
    @State private var showZoneCalibrationSheet: Bool = false
    @State private var showFullOpticalMenuSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Segmented Control: Optische Sensor vs Handmatig
                    Picker("", selection: $inputMode) {
                        Text(store.t(nl: "📸 Optische Sensor (AI)", en: "📸 Optical Sensor (AI)")).tag(0)
                        Text(store.t(nl: "✍️ Handmatige Invoer", en: "✍️ Manual Entry")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)
                    
                    if inputMode == 0 {
                        opticalSensorView
                    } else {
                        manualEntryView
                    }
                    
                    // Smart Hardware Automation Info Card
                    smartHardwareStatusCard
                    
                    // Apply & Save Button
                    Button {
                        applyMeasurementAndTriggerHardware()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(store.t(nl: "Meting Toepassen & Smart Hardware Koppelen", en: "Apply Reading & Trigger Smart Hardware"))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [MycoTheme.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: MycoTheme.blue.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationTitle(store.t(nl: "Klimaat & Sensor Meting", en: "Climate & Sensor Reading"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(nl: "Annuleren", en: "Cancel")) { dismiss() }
                        .foregroundColor(MycoTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFullOpticalMenuSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(MycoTheme.blue)
                    }
                }
            }
            .sheet(isPresented: $showZoneCalibrationSheet) {
                OpticalMeterSetupSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showFullOpticalMenuSheet) {
                MycoOpticalHygrometerView()
                    .environmentObject(store)
            }
            .onAppear {
                initDefaults()
            }
        }
    }
    
    // MARK: - Optical Sensor View
    private var opticalSensorView: some View {
        VStack(spacing: 14) {
            // Viewfinder / Snapshot Box
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 190)
                
                if let img = previewImage ?? opticalManager.lastCapturedPreview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(10)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.metering.matrix")
                            .font(.system(size: 36))
                            .foregroundColor(Color.cyan.opacity(0.8))
                        Text(store.t(nl: "Geen recent camerabeeld", en: "No recent camera frame"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MycoTheme.textSecondary)
                        Text(store.t(nl: "Tik op \"Scan Meter Display Nu\" om direct een foto te maken", en: "Tap \"Scan Meter Display Now\" to capture instantly"))
                            .font(.system(size: 11))
                            .foregroundColor(MycoTheme.textSecondary.opacity(0.7))
                    }
                }
                
                if isScanning {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.65))
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text(scanStatusMessage.isEmpty ? store.t(nl: "AI analyseert display...", en: "AI analyzing display...") : scanStatusMessage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isScanning ? Color.cyan : MycoTheme.border, lineWidth: 1)
            )
            
            // Scan Button
            Button {
                triggerOpticalScan()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isScanning ? "hourglass" : "camera.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                    Text(isScanning ? store.t(nl: "Bezig met scannen...", en: "Scanning...") : store.t(nl: "📸 Scan Meter Display Nu", en: "📸 Scan Meter Display Now"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.cyan.opacity(0.25))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
            
            // Dedicated Zone Calibration Card (User Request!)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder.rectangular")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.cyan)
                    Text(store.t(nl: "Meter Zones & Posities", en: "Meter Zones & Positions"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Text(store.t(
                    nl: "Leest de AI de verkeerde vakjes of staat de meter schuin? Stel hier de interactieve kaders in voor Temperatuur en Luchtvochtigheid.",
                    en: "Is the AI reading wrong digits or is the meter angled? Set interactive bounding boxes for Temperature and Humidity here."
                ))
                .font(.system(size: 11))
                .foregroundColor(MycoTheme.textSecondary)
                
                HStack(spacing: 10) {
                    Button {
                        showZoneCalibrationSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 11))
                            Text(store.t(nl: "📐 Zones Instellen", en: "📐 Adjust Zones"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showFullOpticalMenuSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11))
                            Text(store.t(nl: "⚙️ Volledig Menu", en: "⚙️ Full Menu"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(MycoTheme.blue.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(MycoTheme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
            
            // Editable / Confirmed Scanned Values
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.t(nl: "Herkende Meetwaarden (Aanpasbaar):", en: "Recognized Values (Editable):"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if let conf = recognizedConfidence {
                        Text(String(format: "%.0f%% %@", conf * 100, store.t(nl: "Zekerheid", en: "Confidence")))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(conf > 0.75 ? MycoTheme.green : MycoTheme.amber)
                    }
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t(nl: "Temperatuur (°C)", en: "Temperature (°C)"))
                            .font(.system(size: 11))
                            .foregroundColor(MycoTheme.textSecondary)
                        HStack {
                            Image(systemName: "thermometer.medium")
                                .foregroundColor(MycoTheme.amber)
                            TextField("22.0", text: $tempText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t(nl: "Vochtgehalte (% RV)", en: "Humidity (% RH)"))
                            .font(.system(size: 11))
                            .foregroundColor(MycoTheme.textSecondary)
                        HStack {
                            Image(systemName: "humidity.fill")
                                .foregroundColor(MycoTheme.blue)
                            TextField("85", text: $humidityText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(12)
            .background(MycoTheme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
        }
    }
    
    // MARK: - Manual Entry View
    private var manualEntryView: some View {
        VStack(spacing: 14) {
            // Temperature Input Box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(MycoTheme.amber)
                    Text(store.t(nl: "Temperatuur (°C)", en: "Temperature (°C)"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    TextField("22.0", text: $tempText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                // Quick Temp Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["20.0", "21.5", "22.5", "23.5", "25.0"], id: \.self) { val in
                            Button(val + "°C") {
                                tempText = val
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(tempText == val ? MycoTheme.amber.opacity(0.3) : Color.white.opacity(0.07))
                            .foregroundColor(tempText == val ? MycoTheme.amber : .white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(12)
            .background(MycoTheme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
            
            // Humidity Input Box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "humidity.fill")
                        .foregroundColor(MycoTheme.blue)
                    Text(store.t(nl: "Luchtvochtigheid (% RV)", en: "Humidity (% RH)"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    TextField("85", text: $humidityText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                
                // Quick Humidity Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["75", "80", "85", "90", "95"], id: \.self) { val in
                            Button(val + "%") {
                                humidityText = val
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(humidityText == val ? MycoTheme.blue.opacity(0.3) : Color.white.opacity(0.07))
                            .foregroundColor(humidityText == val ? MycoTheme.blue : .white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(12)
            .background(MycoTheme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
            
            // Date & Notes Box
            VStack(alignment: .leading, spacing: 10) {
                DatePicker(store.t(nl: "Tijdstip van meting", en: "Time of reading"), selection: $measurementDate)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                
                TextField(store.t(nl: "Notitie (bijv. tent gelucht of gesproeid)", en: "Note (e.g. tent misted or aired)"), text: $notes)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
            .padding(12)
            .background(MycoTheme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
        }
    }
    
    // MARK: - Smart Hardware Status Card
    private var smartHardwareStatusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(MycoTheme.green)
                Text(store.t(nl: "Smart Hardware Koppeling", en: "Smart Hardware Link"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(store.db.smartDevices.count) " + store.t(nl: "gekoppeld", en: "paired"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(store.db.smartDevices.isEmpty ? MycoTheme.textSecondary : MycoTheme.green)
            }
            
            if store.db.smartDevices.isEmpty {
                Text(store.t(
                    nl: "Je hebt nog geen slimme apparaten gekoppeld. Deze meting berekent je VPD en klimaatstatus. Koppel Tuya stekkers om automatisch te vernevelen of af te zuigen.",
                    en: "No smart plugs paired yet. This reading updates your VPD. Pair Tuya plugs in Smart Hub to automate misting or exhaust."
                ))
                .font(.system(size: 11))
                .foregroundColor(MycoTheme.textSecondary)
            } else {
                Text(store.t(
                    nl: "Zodra je opslaat, controleert het lab of de RV onder je streefgrens zakt en schakelt direct de aangesloten bevochtiger of afzuiging in/uit.",
                    en: "Upon saving, the lab evaluates whether humidity is below target and instantly switches connected humidifiers or exhaust fans."
                ))
                .font(.system(size: 11))
                .foregroundColor(Color.cyan.opacity(0.9))
            }
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MycoTheme.border, lineWidth: 1))
    }
    
    // MARK: - Actions
    private func initDefaults() {
        if let t = store.db.environmentConfig.manualTempC {
            tempText = String(format: "%.1f", t)
        } else if let st = store.db.environmentConfig.latestSensorTempC {
            tempText = String(format: "%.1f", st)
        }
        
        if let h = store.db.environmentConfig.manualHumidityPct {
            humidityText = String(format: "%.0f", h)
        } else if let sh = store.db.environmentConfig.latestSensorHumidityPct {
            humidityText = String(format: "%.0f", sh)
        }
    }
    
    private func triggerOpticalScan() {
        Task { @MainActor in
            isScanning = true
            scanStatusMessage = store.t(nl: "Camerabeeld ophalen...", en: "Fetching camera frame...")
            
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            
            let frame = await opticalManager.captureCalibrationSnapshot()
            if let img = frame {
                previewImage = img
                scanStatusMessage = store.t(nl: "AI analyseert zones & cijfers...", en: "AI analyzing zones & digits...")
                
                let details = await opticalManager.recognizeMeterTextDetailed(image: img)
                recognizedConfidence = details.confidence
                
                if let t = details.temperature {
                    tempText = String(format: "%.1f", t)
                }
                if let h = details.humidity {
                    humidityText = String(format: "%.0f", h)
                }
                
                if details.temperature != nil || details.humidity != nil {
                    scanStatusMessage = store.t(nl: "Display succesvol uitgelezen!", en: "Display successfully read!")
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                } else {
                    scanStatusMessage = store.t(nl: "Geen cijfers herkend. Tik op \"Zones Instellen\" om kaders aan te passen.", en: "No digits recognized. Tap \"Adjust Zones\" to adjust boxes.")
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    #endif
                }
            } else {
                scanStatusMessage = store.t(nl: "Geen beeld ontvangen van camera.", en: "No image received from camera.")
            }
            
            isScanning = false
        }
    }
    
    private func applyMeasurementAndTriggerHardware() {
        let cleanTemp = tempText.replacingOccurrences(of: ",", with: ".")
        let cleanHum = humidityText.replacingOccurrences(of: ",", with: ".")
        let t = Double(cleanTemp)
        let h = Double(cleanHum)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.recordManualReading(tempC: t, humidityPct: h, date: measurementDate, note: notes)
            if let h = h {
                opticalManager.reactToManualOrExternalReading(humidityPct: h, tempC: t)
            }
        }
        
        let dispTemp = t.map { String(format: "%.1f°C", $0) } ?? "\(tempText)°C"
        let dispHum = h.map { String(format: "%.0f%% RV", $0) } ?? "\(humidityText)% RV"
        
        MycoSyncManager.shared.triggerToast(message: store.t(
            nl: "Klimaatmeting verwerkt (\(dispTemp) • \(dispHum)) & Smart Hardware geactiveerd",
            en: "Climate reading applied (\(dispTemp) • \(dispHum)) & Smart Hardware activated"
        ))
        
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }
}

typealias ManualClimateLogSheet = ClimateMeasurementStudioSheet

// MARK: - LIVING HARDWARE & TELEMETRY STRIP
struct LivingHardwareStrip: View {
    @EnvironmentObject var store: MycoStore
    let onOpenMonitor: () -> Void
    var onOpenBroadcaster: (() -> Void)? = nil
    let onOpenSpaceAndClimate: () -> Void
    let onOpenVoiceAssistant: () -> Void
    
    private var isCamActive: Bool {
        MycoCamStreamManager.shared.connectionState == .connected || MycoCamStreamManager.shared.role != .idle
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
            // Camera Pill
            Button {
                onOpenMonitor()
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isCamActive ? MycoTheme.green.opacity(0.2) : Color.teal.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: isCamActive ? "dot.radiowaves.up.forward" : "video.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isCamActive ? MycoTheme.green : Color.teal)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(isCamActive ? store.t(nl: "Live Feed", en: "Live Feed") : store.t(nl: "Kweekcamera", en: "Grow Camera"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Circle()
                                .fill(isCamActive ? Color.red : MycoTheme.green)
                                .frame(width: 5, height: 5)
                        }
                        Text(isCamActive ? store.t(nl: "Verbonden • Tik om te kijken", en: "Connected • Tap to view") : store.t(nl: "Tik voor live stream", en: "Tap for live stream"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCamActive ? MycoTheme.green.opacity(0.5) : MycoTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Ruimte & Klimaat Pill (Direct access to Space, CFM and Optische RV)
            Button {
                onOpenSpaceAndClimate()
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(MycoTheme.blue.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MycoTheme.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Ruimte & Klimaat", en: "Space & Climate"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(store.t(nl: "CFM, m³ & Optische RV", en: "CFM, m³ & Optical RH"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MycoTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Cleanroom Voice Assistant Pill
            Button {
                onOpenVoiceAssistant()
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.t(nl: "Cleanroom Voice", en: "Cleanroom Voice"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(store.t(nl: "Handsfree Flowhood", en: "Hands-free Flowhood"))
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MycoTheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(MycoTheme.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        }
    }
}

// MARK: - MODERN GROW PROJECT ROW CARD
struct ModernGrowProjectCard: View {
    @EnvironmentObject var store: MycoStore
    let project: GrowProject
    
    var daysActive: Int {
        Calendar.current.dateComponents([.day], from: project.startDate, to: Date()).day ?? 0
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Living Colonization Ring
            LivingColonizationRing(
                progress: project.normalizedColonizationPercent,
                phase: project.phase,
                daysActive: daysActive
            )
            
            // Middle: Information Hierarchy
            VStack(alignment: .leading, spacing: 5) {
                // Strain title & Batch Number
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.displayTitle(name: project.strainName, sku: project.skuCode))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("#\(project.batchNumber)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(MycoTheme.textSecondary)
                    
                    Spacer()
                    
                    // Phase badge (clean pill)
                    Text(project.phase.localized(isEnglish: store.isEnglish))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(project.phase.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(project.phase.color.opacity(0.14))
                        .cornerRadius(6)
                }
                
                // Substrate & Container description
                Text("\(project.containerName.isEmpty ? store.t(nl: "Standaard Setup", en: "Default Setup") : store.localizePresetName(project.containerName)) • \(project.substrateName.isEmpty ? store.t(nl: "Eigen Substraat", en: "Custom Substrate") : store.localizePresetName(project.substrateName))")
                    .font(.caption)
                    .foregroundColor(MycoTheme.textSecondary)
                    .lineLimit(1)
                
                // Telemetry & Tags Bar
                HStack(spacing: 10) {
                    // Temperature capsule
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.amber)
                        Text(project.latestTempC != nil ? String(format: "%.1f°C", project.latestTempC!) : "--°C")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(4)
                    
                    // Humidity capsule
                    HStack(spacing: 4) {
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 10))
                            .foregroundColor(MycoTheme.blue)
                        Text(project.latestHumidityPct != nil ? String(format: "%.0f%%", project.latestHumidityPct!) : "--%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(4)
                    
                    // Biological Efficiency (BE%) Badge if flushes logged
                    if let be = store.bePercent(for: project.id), be > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 8, weight: .bold))
                            Text(String(format: "%.0f%% BE", be))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(be >= 100 ? MycoTheme.green : (be >= 70 ? MycoTheme.amber : MycoTheme.blue))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((be >= 100 ? MycoTheme.green : (be >= 70 ? MycoTheme.amber : MycoTheme.blue)).opacity(0.18))
                        .cornerRadius(4)
                    }
                    
                    // Tags preview (if any)
                    if let firstTag = project.tags.first {
                        Text(firstTag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(firstTag.contains("Quarantaine") ? MycoTheme.red : (firstTag.contains("B&S") ? MycoTheme.amber : MycoTheme.blue))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (firstTag.contains("Quarantaine") ? MycoTheme.red : (firstTag.contains("B&S") ? MycoTheme.amber : MycoTheme.blue)).opacity(0.15)
                            )
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Subtle QR / ID chip
                    Text(project.qrCodeID)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(MycoTheme.textSecondary.opacity(0.7))
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MycoTheme.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(MycoTheme.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

// MARK: - MODERN DASHBOARD TAB VIEW
struct ModernDashboardTabView: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedPhaseFilter: String = "Alle Actief"
    @State private var showCreateBatch = false
    @State private var showSettings = false
    @State private var showAppleAuth = false
    @State private var showRemoteMonitor = false
    @State private var showSpaceCalculator = false
    @State private var showOpticalHygrometerSheet = false
    @State private var showManualClimateLogSheet = false
    @State private var showZoneCalibrationSheet = false
    @State private var showMaintenanceSheet = false
    @State private var showTuyaLabHub = false
    @State private var showCleanroomVoice = false
    @State private var showResetDemoConfirm = false
    @State private var editingProject: GrowProject? = nil
    
    private var isWideGrid: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    private let filterOptions = ["Alle Actief", "Grain Spawn", "Bulk / Kolonisatie", "Vruchtfase", "Gearchiveerd"]
    
    var filteredProjects: [GrowProject] {
        store.db.projects.filter { proj in
            if selectedPhaseFilter == "Gearchiveerd" {
                return proj.isArchived
            }
            if proj.isArchived { return false }
            if selectedPhaseFilter == "Alle Actief" { return true }
            return proj.phase.rawValue == selectedPhaseFilter
        }
    }
    
    var activeBatchesCount: Int {
        store.db.projects.filter { !$0.isArchived }.count
    }
    
    private var hasConfiguredCamera: Bool {
        let pairedCam = UserDefaults.standard.string(forKey: "mycolab_paired_camera_id") ?? ""
        return !pairedCam.isEmpty ||
            !store.db.environmentConfig.effectiveRtspURL.isEmpty ||
            !store.db.environmentConfig.effectiveSnapshotURL.isEmpty ||
            store.db.timelapsePhotos.contains(where: { $0.hasPhotoData }) ||
            MycoCamStreamManager.shared.connectionState == .connected ||
            LiveKitStreamManager.shared.isConnected
    }
    
    private var hasSmartDevices: Bool {
        !store.db.smartDevices.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    if store.db.isDemoMode {
                        demoModeBanner
                    }
                    
                    // MARK: - 1. Serene Lab Status Banner
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.db.stealthMode ? "LabOS Cockpit" : store.t(nl: "Mijn Laboratorium", en: "My Laboratory"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(activeBatchesCount > 0 ? MycoTheme.green : MycoTheme.textSecondary)
                                    .frame(width: 6, height: 6)
                                Text(activeBatchesCount > 0 ? store.t(nl: "\(activeBatchesCount) actieve \(activeBatchesCount == 1 ? "batch" : "batches") • Optimaal", en: "\(activeBatchesCount) active \(activeBatchesCount == 1 ? "batch" : "batches") • Optimal") : store.t(nl: "Lab is gereed voor een nieuwe kweek", en: "Lab is ready for a new grow"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(MycoTheme.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Prominent + Nieuwe Batch button in modern capsule style
                        Button {
                            showCreateBatch = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(store.t(nl: "Batch", en: "Batch"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [MycoTheme.blue, MycoTheme.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: MycoTheme.blue.opacity(0.35), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.top, 4)
                    
                    // MARK: - 1B. Lab Climate & Telemetry Hero Card
                    if store.db.environmentConfig.isMaintenanceModeActive {
                        MaintenanceModeBanner(onTap: { showMaintenanceSheet = true })
                    }
                    
                    LivingLabBioHeroCard(
                        activeBatches: activeBatchesCount,
                        onLogManualClimate: { showManualClimateLogSheet = true }
                    )
                    
                    // MARK: - 1C. Dedicated Grow Camera Module (Only when paired or streaming)
                    if hasConfiguredCamera {
                        LivingGrowCameraCard(
                            onOpenLiveMonitor: { showRemoteMonitor = true },
                            onOpenSpaceAndClimate: { showSpaceCalculator = true }
                        )
                    }
                    
                    // MARK: - 1D. Living Smart Device Quick-Dock (Only when user has paired smart plugs)
                    if hasSmartDevices {
                        LivingSmartDeviceQuickDock(onOpenSmartHub: { showTuyaLabHub = true })
                    }
                    
                    // MARK: - 1E. Modular Lab Expansions Banner (Zero-hardware / progressive upgrade helper)
                    if !hasConfiguredCamera || !hasSmartDevices {
                        modularLabExpansionCard
                    }
                    
                    // MARK: - 3. Clean Phase Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filterOptions, id: \.self) { option in
                                let isSelected = selectedPhaseFilter == option
                                let count: Int = {
                                    if option == "Gearchiveerd" {
                                        return store.db.projects.filter { $0.isArchived }.count
                                    } else if option == "Alle Actief" {
                                        return store.db.projects.filter { !$0.isArchived }.count
                                    } else {
                                        return store.db.projects.filter { !$0.isArchived && $0.phase.rawValue == option }.count
                                    }
                                }()
                                
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        selectedPhaseFilter = option
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(store.localizePhaseFilter(option))
                                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        if count > 0 {
                                            Text("\(count)")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .foregroundColor(isSelected ? .white : MycoTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? MycoTheme.blue : MycoTheme.card)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(isSelected ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // MARK: - 4. Batches Grid or Clean Empty State
                    if filteredProjects.isEmpty {
                        EmptyStateCard(
                            icon: "flask.fill",
                            title: store.t(nl: "Geen batches gevonden", en: "No batches found"),
                            message: store.t(
                                nl: "Je lab is gereed voor gebruik. Maak je eerste kweekproject aan om te starten.",
                                en: "Your lab is ready. Create your first grow project to begin."
                            ),
                            buttonTitle: store.t(nl: "+ Eerste Batch Starten", en: "+ Start First Batch")
                        ) {
                            showCreateBatch = true
                        }
                        .padding(.top, 8)
                    } else if isWideGrid {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 14)], spacing: 14) {
                            ForEach(filteredProjects) { project in
                                NavigationLink(value: project.id) {
                                    ModernGrowProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        editingProject = project
                                    } label: {
                                        Label(store.t(nl: "Bewerk Batch Setup", en: "Edit Batch Setup"), systemImage: "pencil")
                                    }

                                    Divider()

                                    Button {
                                        editingProject = project
                                    } label: {
                                        Label(store.t(nl: "Bewerk Batch Setup", en: "Edit Batch Setup"), systemImage: "pencil")
                                    }

                                    Divider()

                                    Button {
                                        withAnimation {
                                            if let pIdx = store.db.projects.firstIndex(where: { $0.id == project.id }) {
                                                store.db.projects[pIdx].isArchived.toggle()
                                                store.save()
                                            }
                                        }
                                    } label: {
                                        Label(
                                            project.isArchived ? store.t(nl: "Zet terug naar Actief", en: "Restore to Active") : store.t(nl: "Archiveer Batch", en: "Archive Batch"),
                                            systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox"
                                        )
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.deleteProject(id: project.id)
                                        }
                                    } label: {
                                        Label(store.t(nl: "Verwijder Batch", en: "Delete Batch"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredProjects) { project in
                                NavigationLink(value: project.id) {
                                    ModernGrowProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        withAnimation {
                                            if let pIdx = store.db.projects.firstIndex(where: { $0.id == project.id }) {
                                                store.db.projects[pIdx].isArchived.toggle()
                                                store.save()
                                            }
                                        }
                                    } label: {
                                        Label(
                                            project.isArchived ? store.t(nl: "Zet terug naar Actief", en: "Restore to Active") : store.t(nl: "Archiveer Batch", en: "Archive Batch"),
                                            systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox"
                                        )
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            store.deleteProject(id: project.id)
                                        }
                                    } label: {
                                        Label(store.t(nl: "Verwijder Batch", en: "Delete Batch"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(16)
                .padding(.bottom, 60)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MycoLabNewBatchShortcut"))) { _ in
                showCreateBatch = true
            }
            .background(MycoTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showCleanroomVoice = true
                        } label: {
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 16))
                                .foregroundColor(Color.cyan)
                        }
                        .accessibilityLabel("Cleanroom Voice Assistant")
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { projID in
                ProjectDetailView(projectID: projID)
            }
            .sheet(isPresented: $showCreateBatch) {
                CreateBatchSheetView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showAppleAuth) {
                AppleLoginSheetView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showRemoteMonitor) {
                RemoteLabMonitorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showSpaceCalculator) {
                GrowSpaceSizeAndAIClimateView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showOpticalHygrometerSheet) {
                MycoOpticalHygrometerView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showManualClimateLogSheet) {
                ClimateMeasurementStudioSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showZoneCalibrationSheet) {
                OpticalMeterSetupSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showMaintenanceSheet) {
                MaintenanceModeSheet()
                    .environmentObject(store)
            }
            .sheet(item: $editingProject) { proj in
                EditProjectSheetView(project: proj)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTuyaLabHub) {
                SmartEnvironmentHubView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCleanroomVoice) {
                CleanroomVoiceConsoleView()
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Demo Mode Banner
    private var demoModeBanner: some View {
        Button {
            showResetDemoConfirm = true
        } label: {
            HStack(spacing: 8) {
                Text("🧪")
                    .font(.system(size: 14))
                Text(store.t(nl: "Demo Modus Actief", en: "Demo Mode Active"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MycoTheme.amber)
                Text("•")
                    .foregroundColor(MycoTheme.textSecondary)
                Text(store.t(nl: "Tik om naar schoon lab te gaan", en: "Tap to switch to clean lab"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MycoTheme.amber)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MycoTheme.amber.opacity(0.14))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(MycoTheme.amber.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            store.t(nl: "Demo Modus Beëindigen?", en: "Exit Demo Mode?"),
            isPresented: $showResetDemoConfirm,
            titleVisibility: .visible
        ) {
            Button(store.t(nl: "Wis demo data en start Schoon Lab", en: "Clear demo data & start Clean Lab"), role: .destructive) {
                store.resetToCleanLab()
                MycoSyncManager.shared.triggerToast(message: store.t(nl: "Schoon kweeklab gestart!", en: "Clean grow lab started!"))
            }
            Button(store.t(nl: "Behoud Demo Data", en: "Keep Demo Data"), role: .cancel) {}
        } message: {
            Text(store.t(
                nl: "Alle voorbeelddata (oesterzwammen, testsensoren) wordt gewist zodat je met een 100% blanco kweekjournaal kunt starten.",
                en: "All sample data (oyster mushrooms, test sensors) will be cleared so you can start with a 100% blank cultivation journal."
            ))
        }
    }
    
    // MARK: - Modular Lab Expansions Banner
    private var modularLabExpansionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(MycoTheme.green)
                    .font(.system(size: 14))
                Text(store.t(nl: "Lab Modules & Uitbreidingen", en: "Lab Modules & Expansions"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(store.t(nl: "Optioneel", en: "Optional"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
            
            Text(store.t(
                nl: "Kweek eenvoudig handmatig of breid stap voor stap uit met hardware zodra je lab groeit.",
                en: "Grow simply by hand or expand step-by-step with hardware as your lab grows."
            ))
            .font(.system(size: 11))
            .foregroundColor(MycoTheme.textSecondary)
            
            HStack(spacing: 8) {
                if !hasConfiguredCamera {
                    Button {
                        showRemoteMonitor = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                            Text(store.t(nl: "+ Kweekcamera", en: "+ Grow Camera"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.teal.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                
                if !hasSmartDevices {
                    Button {
                        showTuyaLabHub = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 11))
                            Text(store.t(nl: "+ Wifi Stekker", en: "+ Smart Plug"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(MycoTheme.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MycoTheme.blue.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MycoTheme.blue.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(MycoTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MycoTheme.border, lineWidth: 1))
    }
}

// MARK: - MAINTENANCE MODE BANNER
struct MaintenanceModeBanner: View {
    @EnvironmentObject var store: MycoStore
    var onTap: () -> Void = {}
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.25))
                        .frame(width: 38, height: 38)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.t(nl: "Onderhoudsmodus Actief", en: "Maintenance Mode Active"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 7, height: 7)
                    }
                    
                    if let start = store.db.environmentConfig.maintenanceModeStartTime,
                       store.db.environmentConfig.maintenanceModeAutoResumeMinutes > 0 {
                        let elapsed = Int(Date().timeIntervalSince(start) / 60.0)
                        let remaining = max(0, store.db.environmentConfig.maintenanceModeAutoResumeMinutes - elapsed)
                        Text(store.t(
                            nl: "Apparaten bevroren (bezig in ruimte) • Nog ~\(remaining) min",
                            en: "Devices frozen (active in space) • ~\(remaining) min left"
                        ))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                    } else {
                        Text(store.t(
                            nl: "Apparaten bevroren • Tik om te beheren of hervatten",
                            en: "Devices frozen • Tap to manage or resume"
                        ))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        store.setMaintenanceMode(enabled: false)
                    }
                } label: {
                    Text(store.t(nl: "Hervatten", en: "Resume"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .buttonStyle(ModernBouncyButtonStyle())
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.12)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MAINTENANCE MODE SHEET
struct MaintenanceModeSheet: View {
    @EnvironmentObject var store: MycoStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDuration: Int = 30
    
    private let durationOptions: [(titleNL: String, titleEN: String, minutes: Int)] = [
        ("15 minuten", "15 minutes", 15),
        ("30 minuten (Aanbevolen)", "30 minutes (Recommended)", 30),
        ("60 minuten (1 uur)", "60 minutes (1 hour)", 60),
        ("Handmatig (Geen timer)", "Manual (No timer)", 0)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                MycoTheme.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Hero Icon & Explanation
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(store.db.environmentConfig.isMaintenanceModeActive ? Color.orange.opacity(0.2) : Color.white.opacity(0.08))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(store.db.environmentConfig.isMaintenanceModeActive ? .orange : .white)
                            }
                            
                            Text(store.t(nl: "Onderhoudsmodus", en: "Maintenance Mode"))
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            Text(store.t(
                                nl: "Zet dit aan wanneer je bezig bent in de kweekruimte (inspecteren, oogsten, sproeien of schoonmaken). Ventilatoren en bevochtigers worden direct uitgeschakeld om storende tocht en mist in je gezicht te voorkomen. Alle automatische schakelingen (Autopilot, schema's en sensortriggers) worden veilig bevroren.",
                                en: "Enable this when working inside the grow space (inspecting, harvesting, misting, or cleaning). Fans and humidifiers are immediately turned off to avoid disturbing airflow or mist in your face. All automatic cycles (Autopilot, schedules, and sensor triggers) are safely frozen."
                            ))
                            .font(.subheadline)
                            .foregroundColor(MycoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                        }
                        .padding(.top, 10)
                        
                        // Status Card
                        MycoCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(store.t(nl: "Huidige Status", en: "Current Status"))
                                        .font(.caption.bold())
                                        .foregroundColor(MycoTheme.textSecondary)
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(store.db.environmentConfig.isMaintenanceModeActive ? Color.orange : Color.green)
                                            .frame(width: 8, height: 8)
                                        Text(store.db.environmentConfig.isMaintenanceModeActive
                                             ? store.t(nl: "Actief (Apparaten bevroren)", en: "Active (Devices frozen)")
                                             : store.t(nl: "Niet actief (Normale werking)", en: "Inactive (Normal operation)"))
                                            .font(.caption.bold())
                                            .foregroundColor(store.db.environmentConfig.isMaintenanceModeActive ? .orange : .green)
                                    }
                                }
                                
                                if store.db.environmentConfig.isMaintenanceModeActive,
                                   let start = store.db.environmentConfig.maintenanceModeStartTime {
                                    Divider().background(MycoTheme.border)
                                    
                                    let elapsed = Int(Date().timeIntervalSince(start) / 60.0)
                                    HStack {
                                        Text(store.t(nl: "Verstreken tijd:", en: "Elapsed time:"))
                                            .font(.caption)
                                            .foregroundColor(MycoTheme.textSecondary)
                                        Spacer()
                                        Text("\(elapsed) " + store.t(nl: "minuten", en: "minutes"))
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                    
                                    if store.db.environmentConfig.maintenanceModeAutoResumeMinutes > 0 {
                                        let remaining = max(0, store.db.environmentConfig.maintenanceModeAutoResumeMinutes - elapsed)
                                        HStack {
                                            Text(store.t(nl: "Automatisch hervatten over:", en: "Auto-resumes in:"))
                                                .font(.caption)
                                                .foregroundColor(MycoTheme.textSecondary)
                                            Spacer()
                                            Text("~\(remaining) " + store.t(nl: "minuten", en: "minutes"))
                                                .font(.caption.bold())
                                                .foregroundColor(.orange)
                                        }
                                    } else {
                                        HStack {
                                            Text(store.t(nl: "Herstelmodus:", en: "Resume mode:"))
                                                .font(.caption)
                                                .foregroundColor(MycoTheme.textSecondary)
                                            Spacer()
                                            Text(store.t(nl: "Handmatig uitschakelen", en: "Manual turn off"))
                                                .font(.caption.bold())
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Safety Timer Selection
                        MycoCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "timer")
                                        .foregroundColor(Color.orange)
                                    Text(store.t(nl: "Automatische Hersteltimer", en: "Auto-Resume Safety Timer"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                
                                Text(store.t(
                                    nl: "Voorkomt dat de kweekruimte uren of dagen stil blijft staan als je vergeet de modus weer uit te schakelen.",
                                    en: "Prevents the grow space from staying frozen for hours or days if you forget to turn the mode off."
                                ))
                                .font(.caption)
                                .foregroundColor(MycoTheme.textSecondary)
                                
                                ForEach(durationOptions, id: \.minutes) { opt in
                                    let isSelected = selectedDuration == opt.minutes
                                    Button {
                                        selectedDuration = opt.minutes
                                        store.db.environmentConfig.maintenanceModeAutoResumeMinutes = opt.minutes
                                        store.save()
                                    } label: {
                                        HStack {
                                            Text(store.t(nl: opt.titleNL, en: opt.titleEN))
                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(.white)
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color.orange)
                                            } else {
                                                Circle()
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                                    .frame(width: 18, height: 18)
                                            }
                                        }
                                        .padding(10)
                                        .background(isSelected ? Color.orange.opacity(0.15) : Color.white.opacity(0.04))
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Action Button
                        if store.db.environmentConfig.isMaintenanceModeActive {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    store.setMaintenanceMode(enabled: false)
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text(store.t(nl: "Onderhoudsmodus Beëindigen & Hervatten", en: "End Maintenance & Resume"))
                                }
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .cornerRadius(12)
                                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 3)
                            }
                            .buttonStyle(ModernBouncyButtonStyle())
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    store.setMaintenanceMode(enabled: true, durationMinutes: selectedDuration)
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                    Text(store.t(nl: "Schakel Onderhoudsmodus In", en: "Activate Maintenance Mode"))
                                }
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .cornerRadius(12)
                                .shadow(color: Color.orange.opacity(0.35), radius: 8, x: 0, y: 3)
                            }
                            .buttonStyle(ModernBouncyButtonStyle())
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(store.t(nl: "Kweekruimte Onderhoud", en: "Room Maintenance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(nl: "Sluit", en: "Close")) {
                        dismiss()
                    }
                    .foregroundColor(MycoTheme.textSecondary)
                }
            }
            .onAppear {
                selectedDuration = store.db.environmentConfig.maintenanceModeAutoResumeMinutes
            }
        }
    }
}
