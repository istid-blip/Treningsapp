import SwiftUI
import Combine

enum CircuitState {
    case idle           // Før start
    case getReady       // Nedtelling FØR et aktivt segment (ikke før pause)
    case executing      // Utfører segmentet (enten det er jobb eller pause)
    case completed      // Ferdig
}

struct RunCircuitView: View {
    let routine: CircuitRoutine
    
    @State private var currentState: CircuitState = .idle
    @State private var currentSegmentIndex = 0
    
    // Tellere
    @State private var timeRemaining = 0
    @State private var elapsedTime = 0
    
    @State private var timerActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack {
                if currentState == .completed {
                    completedView
                } else {
                    activeSegmentView
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onReceive(timer) { _ in
            guard timerActive else { return }
            updateTimer()
        }
    }
    
    // --- UI DELER ---
    
    var activeSegmentView: some View {
        VStack(spacing: 40) {
            // Progress
            Text("Segment \(currentSegmentIndex + 1) av \(routine.segments.count)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top)
            
            Spacer()
            
            VStack(spacing: 20) {
                Text(statusTitle)
                    .font(.title2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                
                // Navn på segmentet
                Text(currentSegment.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            
            // Sirkelen med info
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.3)
                    .foregroundColor(.white)
                
                VStack {
                    if currentState == .getReady {
                        Text("\(timeRemaining)")
                            .font(.system(size: 100, weight: .bold, design: .rounded))
                    } else {
                        // EXECUTING
                        switch currentSegment.type {
                        case .duration, .pause:
                            Text("\(timeRemaining)")
                                .font(.system(size: 100, weight: .bold, design: .rounded))
                        case .reps:
                            Text("\(currentSegment.targetReps)")
                                .font(.system(size: 80, weight: .bold))
                            Text("REPS")
                                .font(.title3)
                        case .stopwatch:
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 70, weight: .bold, design: .monospaced))
                        }
                    }
                }
                .foregroundStyle(.white)
            }
            .frame(width: 280, height: 280)
            .padding()
            
            Spacer()
            
            // Knapperad
            HStack(spacing: 40) {
                if currentState != .idle {
                    Button(action: { timerActive.toggle() }) {
                        Image(systemName: timerActive ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 70, height: 70)
                            .foregroundStyle(.white)
                    }
                }
                
                // Ferdig-knapp / Hopp over
                // Vises hvis vi er idle, eller hvis vi må trykke manuelt (reps/stopwatch),
                // eller hvis brukeren vil hoppe over en pause/timer.
                Button(action: {
                    if currentState == .idle {
                        startNextSegment()
                    } else {
                        finishCurrentSegment()
                    }
                }) {
                    Text(currentState == .idle ? "Start Økt" : "Neste >")
                        .font(.headline)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(30)
                }
            }
            .padding(.bottom, 50)
        }
    }
    
    var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
            Text("Godt jobbet!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
        }
    }
    
    // --- LOGIKK ---
    
    var currentSegment: CircuitExercise {
        if currentSegmentIndex < routine.segments.count {
            return routine.segments[currentSegmentIndex]
        }
        return routine.segments[0]
    }
    
    var backgroundColor: Color {
        if currentState == .completed { return .blue }
        if currentState == .idle { return .gray }
        if currentState == .getReady { return .yellow }
        
        // Farge basert på segment-type
        if currentSegment.type == .pause { return .orange }
        return .green
    }
    
    var statusTitle: String {
        if currentState == .getReady { return "Gjør deg klar" }
        if currentSegment.type == .pause { return "Slapp av" }
        return "Jobb på!"
    }
    
    func formatTime(_ s: Int) -> String {
        let min = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", min, sec)
    }
    
    // Kalles hvert sekund
    func updateTimer() {
        if currentState == .getReady {
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { enterSegment() }
        }
        else if currentState == .executing {
            switch currentSegment.type {
            case .duration, .pause:
                if timeRemaining > 0 { timeRemaining -= 1 }
                else { finishCurrentSegment() }
            case .stopwatch:
                elapsedTime += 1
            case .reps:
                break // Venter på manuelt trykk
            }
        }
    }
    
    // Starter logikken for neste segment
    func startNextSegment() {
        // Skal vi ha "Get Ready" før dette segmentet?
        // Ja, hvis det er en aktiv øvelse. Nei, hvis det er en pause.
        let isActiveExercise = currentSegment.type != .pause
        
        if isActiveExercise {
            currentState = .getReady
            timeRemaining = 5
            timerActive = true
        } else {
            // Hvis det er pause, start pausen direkte
            enterSegment()
        }
    }
    
    // Går fra GetReady -> Executing
    func enterSegment() {
        currentState = .executing
        timerActive = true
        elapsedTime = 0
        
        // Sett opp tid basert på type
        if currentSegment.type == .duration || currentSegment.type == .pause {
            timeRemaining = currentSegment.durationSeconds
        } else {
            timeRemaining = 0
        }
    }
    
    // Når segmentet er ferdig
    func finishCurrentSegment() {
        if currentSegmentIndex < routine.segments.count - 1 {
            currentSegmentIndex += 1
            startNextSegment()
        } else {
            timerActive = false
            currentState = .completed
        }
    }
}
