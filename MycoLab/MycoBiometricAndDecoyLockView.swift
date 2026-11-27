//
//  MycoBiometricAndDecoyLockView.swift
//  MycoLab
//
//  Lock Screen with Face ID / Touch ID + Duress / Decoy PIN support:
//  - Face ID / Touch ID unlocks authentic laboratory
//  - Entering Master PIN ("1234") unlocks authentic laboratory
//  - Entering Decoy PIN ("9999") unlocks innocent culinary oyster mushroom vault (Decoy Mode)
//  - InfoTipButton explains Duress security
//

import SwiftUI

struct MycoBiometricAndDecoyLockView: View {
    @EnvironmentObject var store: MycoStore
    
    @State private var enteredPin: String = ""
    @State private var isErrorShaking: Bool = false
    @State private var showPinPad: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Biometric Icon / Shield
            ZStack {
                Circle()
                    .fill(MycoTheme.blue.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: showPinPad ? "lock.fill" : MycoDevicePlatform.biometricIcon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(MycoTheme.blue)
            }
            
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(store.db.stealthMode ? (store.isEnglish ? "LabOS Secured" : "LabOS Beveiligd") : (store.isEnglish ? "MycoLabs Secured" : "MycoLabs Beveiligd"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    InfoTipButton(
                        title: store.t(nl: "Lab Beveiliging & Gastprofiel", en: "Lab Security & Guest Profile"),
                        message: store.t(
                            nl: "Ontgrendel veilig met Face ID, Touch ID of je Beheerder PIN. Voer de Gastcode in (standaard 9999) om direct te ontgrendelen in een veilige gastweergave met culinaire kweekprojecten.",
                            en: "Unlock securely with Face ID, Touch ID or your Master PIN. Enter the Guest PIN (default 9999) to immediately open in a guest profile showing culinary cultivation projects."
                        )
                    )
                }
                
                Text(showPinPad
                     ? store.t(nl: "Voer je 4-cijferige pincode in", en: "Enter your 4-digit PIN")
                     : (MycoDevicePlatform.isMac
                        ? store.t(nl: "Gebruik Touch ID of je wachtwoord om te ontgrendelen", en: "Use Touch ID or password to unlock")
                        : store.t(nl: "Scan je gezicht om toegang te krijgen tot je laboratorium data", en: "Scan your face to access your laboratory data")))
                    .font(.subheadline)
                    .foregroundColor(MycoTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if !showPinPad {
                // Primary Biometric Button
                Button {
                    store.authenticateBiometrics()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: MycoDevicePlatform.biometricIcon)
                        Text(store.t(nl: "Ontgrendel met \(MycoDevicePlatform.biometricName)", en: "Unlock with \(MycoDevicePlatform.biometricName)"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: 340)
                    .padding(.vertical, 14)
                    .background(MycoTheme.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 6)
                
                // Toggle to Keypad
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showPinPad = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "number.square")
                        Text(store.t(nl: "Voer Pincode In (Beheerder of Gast PIN)", en: "Enter PIN (Master or Guest PIN)"))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MycoTheme.textSecondary)
                    .padding(.top, 4)
                }
                
                Spacer()
            } else {
                // PIN Dots
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < enteredPin.count ? MycoTheme.blue : Color.white.opacity(0.15))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(index < enteredPin.count ? MycoTheme.blue : MycoTheme.border, lineWidth: 1)
                            )
                    }
                }
                .padding(.vertical, 8)
                .offset(x: isErrorShaking ? -10 : 0)
                .animation(isErrorShaking ? Animation.default.repeatCount(4).speed(3) : .default, value: isErrorShaking)
                
                // Numeric Keypad
                VStack(spacing: 10) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 16) {
                            ForEach(1...3, id: \.self) { col in
                                let digit = "\(row * 3 + col)"
                                keypadButton(digit)
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        // Switch back to Biometrics
                        Button {
                            withAnimation {
                                showPinPad = false
                                enteredPin = ""
                            }
                        } label: {
                            Image(systemName: MycoDevicePlatform.biometricIcon)
                                .font(.system(size: 20))
                                .foregroundColor(MycoTheme.blue)
                                .frame(width: 68, height: 50)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                        }
                        
                        keypadButton("0")
                        
                        // Backspace
                        Button {
                            if !enteredPin.isEmpty {
                                enteredPin.removeLast()
                            }
                        } label: {
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: 18))
                                .foregroundColor(MycoTheme.textSecondary)
                                .frame(width: 68, height: 50)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.top, 6)
                
                Spacer()
            }
            
            Text(store.t(nl: "Eénmalige verificatie bij het opstarten van de app", en: "One-time verification when opening the app"))
                .font(.caption2)
                .foregroundColor(MycoTheme.textSecondary.opacity(0.7))
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MycoTheme.bg.ignoresSafeArea())
        .onAppear {
            store.triggerStartupBiometrics()
        }
    }
    
    private func keypadButton(_ digit: String) -> some View {
        Button {
            handleDigitInput(digit)
        } label: {
            Text(digit)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 68, height: 50)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
        }
    }
    
    private func handleDigitInput(_ digit: String) {
        guard enteredPin.count < 4 else { return }
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        
        enteredPin.append(digit)
        
        if enteredPin.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                checkPin(enteredPin)
            }
        }
    }
    
    private func checkPin(_ pin: String) {
        let decoy = store.db.decoyPin.isEmpty ? MycoDecoyVaultManager.defaultDecoyPin : store.db.decoyPin
        let master = store.db.masterPin.isEmpty ? "1234" : store.db.masterPin
        
        if pin == decoy {
            // DURESS / DECOY PIN ENTERED!
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            store.enterDecoyMode()
        } else if pin == master {
            // AUTHENTIC MASTER PIN ENTERED!
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            store.isUnlocked = true
        } else {
            // WRONG PIN
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            isErrorShaking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isErrorShaking = false
                enteredPin = ""
            }
        }
    }
}
