//
//  StopwatchComponents.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 15/02/2026.
//
import SwiftUI
import SwiftData
import Combine
import UIKit // For UIImpactFeedbackGenerator

// MARK: - Stopwatch Manager
/// Denne klassen fungerer som "hjernen" for tidtakingen.
/// Den holder styr på hvilket segment (øvelse) som er aktivt, og oppdaterer
/// datamodellen (CircuitExercise) direkte hvert sekund.
/// Dette gjør at tiden fortsetter å gå selv om brukeren minimerer stoppeklokke-visningen.
class StopwatchManager: ObservableObject {
    @Published var activeSegmentID: PersistentIdentifier? = nil
    private var timer: Timer?
    
    /// Starter eller stopper tiden for et gitt segment basert på nåværende status.
    func toggle(_ segment: CircuitExercise) {
        if activeSegmentID == segment.persistentModelID {
            stop()
        } else {
            start(segment)
        }
    }
    
    /// Starter en timer som oppdaterer segmentets `durationSeconds` hvert sekund.
    func start(_ segment: CircuitExercise) {
        // Sikre at vi kun har én aktiv timer om gangen
        stop()
        
        activeSegmentID = segment.persistentModelID
        
        // Start ny timer som oppdaterer modellen direkte
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                segment.durationSeconds += 1
            }
        }
    }
    
    /// Stopper aktiv timer og nullstiller referansen.
    func stop() {
        timer?.invalidate()
        timer = nil
        activeSegmentID = nil
    }
    
    /// Sjekker om tiden går for et spesifikt segment.
    func isRunning(_ segment: CircuitExercise) -> Bool {
        return activeSegmentID == segment.persistentModelID
    }
}

// MARK: - Stopwatch View
/// Visuell representasjon av stoppeklokken.
/// Den kan brukes i to moduser:
/// 1. Koblet til `StopwatchManager` (Global timer): Oppdaterer seg mot en aktiv økt.
/// 2. Frittstående (Lokal timer): Brukes f.eks. i historikk-visning hvor man bare redigerer et tall.
struct StopwatchView: View {
    @Binding var bindingTime: Int
    var allowResuming: Bool = true
    
    // Kobling mot global manager (valgfritt)
    var segment: CircuitExercise? = nil
    var manager: StopwatchManager? = nil
    
    @State private var elapsedTime: Double = 0.0
    @State private var isRunning = false
    
    // Lokal timer oppdaterer UI oftere (0.1s) for smooth animasjon,
    // mens manageren oppdaterer databasen sjeldnere (1.0s).
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Button(action: toggleStopwatch) {
                ZStack {
                    // Sirkel-bakgrunn som endrer farge
                    Circle()
                        .fill(isRunning ? Color.orange : Color.green)
                        .shadow(color: (isRunning ? Color.orange : Color.green).opacity(0.4), radius: 15, x: 0, y: 5)
                    
                    // "Puls"-effekt når den kjører
                    if isRunning {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRunning)
                    }
                    
                    // Selve tiden og ikonet
                    VStack(spacing: 5) {
                        Text(formatDetailedTime(elapsedTime))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: elapsedTime))
                        
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 190, height: 190)
            }
            .buttonStyle(ScaleButtonStyle()) // NB: Denne ligger nå i CircuitHelpers.swift
        }
        .onAppear {
            syncState()
        }
        .onChange(of: bindingTime) { _, newValue in
            // Hvis manageren oppdaterer tiden i bakgrunnen, synkroniser visningen
            if isRunning && abs(Double(newValue) - elapsedTime) > 1.0 {
                 elapsedTime = Double(newValue)
            }
            // Sikkerhetsmekanisme
            if newValue == 0 && !isRunning {
                elapsedTime = 0.0
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            elapsedTime += 0.1
            
            if manager == nil {
                // Ingen manager: Vi eier sannheten, oppdater binding direkte.
                bindingTime = Int(elapsedTime)
            } else {
                // Med manager: Synkroniser bindingen visuelt hvert sekund.
                // Manageren tar seg av databasen i bakgrunnen.
                if Int(elapsedTime * 10) % 10 == 0 {
                    bindingTime = Int(elapsedTime)
                }
            }
        }
        // Merk: Vi stopper ikke manageren i onDisappear, for vi vil at den skal kjøre i bakgrunnen.
    }
    
    private func syncState() {
        if let mgr = manager, let seg = segment {
            // Sjekk om global timer allerede går for denne
            if mgr.isRunning(seg) {
                isRunning = true
                elapsedTime = Double(seg.durationSeconds)
            } else if allowResuming {
                elapsedTime = Double(bindingTime)
            } else {
                elapsedTime = 0.0
            }
        } else {
            // Fallback (uten manager)
            if allowResuming {
                elapsedTime = Double(bindingTime)
            } else {
                elapsedTime = 0.0
                if bindingTime != 0 { bindingTime = 0 }
            }
        }
    }
    
    func toggleStopwatch() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isRunning.toggle()
        
        if let mgr = manager, let seg = segment {
            mgr.toggle(seg)
        }
    }
    
    func formatDetailedTime(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
