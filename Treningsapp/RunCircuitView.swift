import SwiftUI
import Combine

enum CircuitState {
    case idle           // Før start
    case getReady       // Nedtelling FØR et aktivt segment
    case executing      // Utfører segmentet
    case completed      // Ferdig
}

struct RunCircuitView: View {
    @Environment(\.dismiss) var dismiss // --- ENDRING: For å kunne lukke viewet ---
    let routine: CircuitRoutine
    
    @State private var currentState: CircuitState = .idle
    @State private var currentSegmentIndex = 0
    
    // UI-Tellere
    @State private var timeRemaining = 0
    @State private var elapsedTime = 0
    
    @State private var timerActive = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // --- ENDRING: Bakgrunnssikker tidtaking ---
    // Vi lagrer absolutte datoer for når ting skal være ferdig.
    @State private var countdownTargetDate: Date? // For nedtelling
    @State private var stopwatchStartDate: Date?  // For stoppeklokke
    
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
                    // --- ENDRING: Bruker toggleTimer() funksjon i stedet for direkte .toggle() ---
                    Button(action: { toggleTimer() }) {
                        Image(systemName: timerActive ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 70, height: 70)
                            .foregroundStyle(.white)
                    }
                }
                
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
            
            // --- ENDRING: Avslutt-knapp ---
            Button(action: { dismiss() }) {
                Text("Avslutt økt")
                    .font(.headline)
                    .padding()
                    .frame(width: 200)
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 30)
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
    
    // --- ENDRING: Ny logikk for timer PAUSE/START ---
    func toggleTimer() {
        timerActive.toggle()
        
        if timerActive {
            // Vi starter opp igjen: Beregn nye måltidspunkter basert på nåtid
            if currentState == .getReady || currentSegment.type == .duration || currentSegment.type == .pause {
                // Nedtelling: Målet er NÅ + det som gjensto
                countdownTargetDate = Date().addingTimeInterval(Double(timeRemaining))
            } else if currentSegment.type == .stopwatch {
                // Stoppeklokke: Startet opprinnelig for (elapsedTime) siden
                stopwatchStartDate = Date().addingTimeInterval(-Double(elapsedTime))
            }
        } else {
            // Vi pauser: Datoene nulles ut, men timeRemaining/elapsedTime bevares (State)
            countdownTargetDate = nil
            stopwatchStartDate = nil
        }
    }

    // --- ENDRING: Robust tidtaking ---
    func updateTimer() {
        if currentState == .getReady {
            // Sjekk mot klokka i stedet for å trekke fra 1
            guard let target = countdownTargetDate else { return }
            let diff = target.timeIntervalSinceNow
            timeRemaining = max(0, Int(ceil(diff)))
            
            if timeRemaining == 0 { enterSegment() }
        }
        else if currentState == .executing {
            switch currentSegment.type {
            case .duration, .pause:
                guard let target = countdownTargetDate else { return }
                let diff = target.timeIntervalSinceNow
                timeRemaining = max(0, Int(ceil(diff)))
                
                if timeRemaining == 0 { finishCurrentSegment() }
                
            case .stopwatch:
                guard let start = stopwatchStartDate else { return }
                let diff = Date().timeIntervalSince(start)
                elapsedTime = Int(diff)
                
            case .reps:
                break // Venter på manuelt trykk
            }
        }
    }
    
    func startNextSegment() {
        let isActiveExercise = currentSegment.type != .pause
        
        if isActiveExercise {
            currentState = .getReady
            timeRemaining = 5
            timerActive = true
            // Sett mål-tid for Get Ready
            countdownTargetDate = Date().addingTimeInterval(5)
        } else {
            enterSegment()
        }
    }
    
    func enterSegment() {
        currentState = .executing
        timerActive = true
        elapsedTime = 0
        
        if currentSegment.type == .duration || currentSegment.type == .pause {
            timeRemaining = currentSegment.durationSeconds
            // Sett mål-tid for nedtelling
            countdownTargetDate = Date().addingTimeInterval(Double(timeRemaining))
        } else if currentSegment.type == .stopwatch {
            timeRemaining = 0
            // Sett start-tid for stoppeklokke
            stopwatchStartDate = Date()
        } else {
            // Reps: Trenger ingen timer-dato
            timeRemaining = 0
        }
    }
    
    func finishCurrentSegment() {
        // Nullstill timere
        countdownTargetDate = nil
        stopwatchStartDate = nil
        
        if currentSegmentIndex < routine.segments.count - 1 {
            currentSegmentIndex += 1
            startNextSegment()
        } else {
            timerActive = false
            currentState = .completed
        }
    }
}
