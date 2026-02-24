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
    static let shared = StopwatchManager()
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
    
    // Timer for rask oppdatering av UI
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Button(action: toggleStopwatch) {
                ZStack {
                    // Bakgrunnssirkel med glød
                    Circle()
                        .fill(isRunning ? Color.orange : Color.green)
                        // Litt kraftigere skygge når den er aktiv for mer "pop"
                        .shadow(color: (isRunning ? Color.orange : Color.green).opacity(isRunning ? 0.6 : 0.4), radius: isRunning ? 20 : 15, x: 0, y: 5)
                    
                    // Animerende "puls" ring når den kjører
                    if isRunning {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .scaleEffect(1.15)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRunning)
                    }
                    
                    // INNHOLDET I SIRKELEN
                    VStack(spacing: 4) {
                        // Vi splitter tiden i to deler for bedre layout
                        let timeParts = splitTime(elapsedTime)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            // Hovedtid (MM:SS) - Stor og tydelig
                            Text(timeParts.main)
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .monospacedDigit() // Hindrer tallene i å hoppe
                            
                            // Hundredeler (.hh) - Mindre og litt dusere
                            Text(timeParts.hundredths)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .foregroundStyle(.white)
                        .offset(y: 4) // Justerer litt ned for optisk balanse
                        
                        // Ikon for Play/Pause
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                // Har økt størrelsen litt fra 190 til 200 for bedre plass
                .frame(width: 200, height: 200)
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
    
}
func splitTime(_ totalSeconds: Double) -> (main: String, hundredths: String) {
    let minutes = Int(totalSeconds) / 60
    let seconds = Int(totalSeconds) % 60
    let hundredths = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)
    
    let mainStr = String(format: "%02d:%02d", minutes, seconds)
    let hundStr = String(format: ".%02d", hundredths)
    
    return (mainStr, hundStr)
}
