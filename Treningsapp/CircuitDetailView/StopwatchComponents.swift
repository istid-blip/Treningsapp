//
//  StopwatchComponents.swift
//  Treningsapp
//

import SwiftUI
import SwiftData
import Combine
import UIKit

// MARK: - Stopwatch Manager
class StopwatchManager: ObservableObject {
    @Published var activeSegmentID: PersistentIdentifier? = nil
    
    private var startTimestamp: Double = 0.0
    private var accumulatedTime: Double = 0.0
    private var activeSegment: CircuitExercise? = nil
    
    func toggle(_ segment: CircuitExercise) {
        if activeSegmentID == segment.persistentModelID {
            stop()
        } else {
            start(segment)
        }
    }
    
    func start(_ segment: CircuitExercise) {
        stop()
        
        activeSegment = segment
        activeSegmentID = segment.persistentModelID
        
        accumulatedTime = segment.durationSeconds
        startTimestamp = Date().timeIntervalSince1970
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func stop() {
        if let segment = activeSegment {
            // Skriver nøyaktig totaltid med desimaler til databasen
            let total = accumulatedTime + (Date().timeIntervalSince1970 - startTimestamp)
            segment.durationSeconds = total
        }
        
        activeSegmentID = nil
        activeSegment = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func isRunning(_ segment: CircuitExercise) -> Bool {
        return activeSegmentID == segment.persistentModelID
    }
    
    func getCurrentTime(for segment: CircuitExercise) -> Double {
        if isRunning(segment) {
            return accumulatedTime + (Date().timeIntervalSince1970 - startTimestamp)
        }
        return segment.durationSeconds
    }
}

// MARK: - Stopwatch View
struct StopwatchView: View {
    @Binding var bindingTime: Int
    var allowResuming: Bool = true
    
    var segment: CircuitExercise? = nil
    var manager: StopwatchManager? = nil
    
    @State private var elapsedTime: Double = 0.0
    @State private var isRunning = false
    
    @State private var localStartTimestamp: Double = 0.0
    @State private var localAccumulatedTime: Double = 0.0
    
    // Oppdaterer visningen raskt for smooth hundredels-animasjon
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Button(action: toggleStopwatch) {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.orange : Color.green)
                        .shadow(color: (isRunning ? Color.orange : Color.green).opacity(0.4), radius: 15, x: 0, y: 5)
                    
                    if isRunning {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRunning)
                    }
                    
                    VStack(spacing: 5) {
                        Text(formatDetailedTime(elapsedTime))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            // Fjerner contentTransition for desimaler, da standard numericText glitchet litt
                        
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 190, height: 190)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .onAppear {
            syncState()
        }
        .onChange(of: segment) { _, _ in
            syncState()
        }
        .onChange(of: bindingTime) { _, newValue in
            if !isRunning {
                elapsedTime = Double(newValue)
            }
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            
            if let mgr = manager, let seg = segment {
                elapsedTime = mgr.getCurrentTime(for: seg)
            } else {
                elapsedTime = localAccumulatedTime + (Date().timeIntervalSince1970 - localStartTimestamp)
            }
        }
    }
    
    private func syncState() {
        if let mgr = manager, let seg = segment {
            if mgr.isRunning(seg) {
                isRunning = true
                elapsedTime = mgr.getCurrentTime(for: seg)
            } else {
                isRunning = false
                elapsedTime = seg.durationSeconds
            }
        } else {
            isRunning = false
            elapsedTime = Double(bindingTime)
            localAccumulatedTime = Double(bindingTime)
        }
    }
    
    func toggleStopwatch() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let mgr = manager, let seg = segment {
            mgr.toggle(seg)
            isRunning = mgr.isRunning(seg)
            if !isRunning {
                // Returnerer nærmeste heltall til rulle-linjalen, men den ekte
                // desimaltiden er trygt lagret i segment.durationSeconds via manageren.
                bindingTime = Int(seg.durationSeconds)
                elapsedTime = seg.durationSeconds
            }
        } else {
            isRunning.toggle()
            if isRunning {
                localStartTimestamp = Date().timeIntervalSince1970
                localAccumulatedTime = Double(bindingTime)
            } else {
                let total = localAccumulatedTime + (Date().timeIntervalSince1970 - localStartTimestamp)
                bindingTime = Int(total)
                elapsedTime = total
            }
        }
    }
    
    func formatDetailedTime(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let hundredths = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)
        
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}
