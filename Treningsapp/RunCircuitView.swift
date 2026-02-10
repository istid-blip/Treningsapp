import SwiftUI
import SwiftData
import AVFoundation
import Combine // <--- DENNE MANGLER

struct RunCircuitView: View {
    @Bindable var routine: CircuitRoutine
    @Environment(\.dismiss) var dismiss
    
    // --- STATE ---
    @State private var sortedSegments: [CircuitExercise] = []
    @State private var currentIndex = 0
    @State private var isPaused = false
    @State private var timerValue = 0
    @State private var isWorkoutComplete = false
    
    // Timer trigger: Kjører hvert sekund
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let theme = AppTheme.standard
    
    var currentSegment: CircuitExercise? {
        if sortedSegments.indices.contains(currentIndex) {
            return sortedSegments[currentIndex]
        }
        return nil
    }
    
    var nextSegment: CircuitExercise? {
        if sortedSegments.indices.contains(currentIndex + 1) {
            return sortedSegments[currentIndex + 1]
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // 1. BAKGRUNNSFARGE
            if let segment = currentSegment {
                theme.color(for: segment.category)
                    .opacity(0.1)
                    .ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
            
            if isWorkoutComplete {
                WorkoutCompletedView(routineName: routine.name, onDismiss: { dismiss() })
            } else if let segment = currentSegment {
                VStack(spacing: 30) {
                    
                    // --- TOPP BAR (Fremgang) ---
                    ProgressView(value: Double(currentIndex), total: Double(max(1, sortedSegments.count)))
                        .tint(theme.color(for: segment.category))
                        .padding(.horizontal)
                    
                    // --- HOVEDINNHOLD ---
                    VStack(spacing: 20) {
                        
                        // Kategori Badge
                        Text(segment.category.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(8)
                            .background(theme.color(for: segment.category).opacity(0.2))
                            .foregroundStyle(theme.color(for: segment.category))
                            .clipShape(Capsule())
                        
                        // Øvelsesnavn
                        Text(segment.name.isEmpty ? segment.category.rawValue : segment.name)
                            .font(.system(size: 36, weight: .bold))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                            .padding(.horizontal)
                        
                        // Vekt / Distanse info
                        if segment.weight > 0 || segment.distance > 0 {
                            HStack {
                                if segment.weight > 0 {
                                    Label("\(Int(segment.weight)) kg", systemImage: "scalemass")
                                }
                                if segment.distance > 0 {
                                    Label("\(Int(segment.distance)) m", systemImage: "figure.run")
                                }
                            }
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        }
                        
                        // Notater
                        if !segment.note.isEmpty {
                            Text(segment.note)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                    
                    // --- TIMER / TELLER SIRKEL ---
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        
                        Circle()
                            .trim(from: 0, to: progressForSegment(segment))
                            .stroke(
                                theme.color(for: segment.category),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerValue)
                        
                        VStack {
                            Text(mainDisplayValue(for: segment))
                                .font(.system(size: 80, weight: .bold, design: .rounded))
                                .contentTransition(.numericText(value: Double(timerValue)))
                            
                            Text(subLabel(for: segment))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 40)
                    .frame(maxWidth: 350)
                    
                    Spacer()
                    
                    // --- NESTE ØVELSE PREVIEW ---
                    if let next = nextSegment {
                        HStack {
                            Text("Neste:")
                                .foregroundStyle(.secondary)
                            Text(next.name.isEmpty ? next.category.rawValue : next.name)
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                        .padding(.horizontal)
                    } else {
                        Color.clear.frame(height: 60)
                    }
                    
                    // --- KONTROLLER ---
                    HStack(spacing: 40) {
                        // Forrige
                        Button(action: previousSegment) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundStyle(currentIndex > 0 ? Color.primary : Color.gray.opacity(0.3))
                        }
                        .disabled(currentIndex == 0)
                        
                        // Play / Pause / Ferdig
                        Button(action: togglePauseOrNext) {
                            ZStack {
                                Circle()
                                    .fill(theme.color(for: segment.category))
                                    .frame(width: 80, height: 80)
                                    .shadow(radius: 5)
                                
                                Image(systemName: actionIconName(for: segment))
                                    .font(.system(size: 35, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        
                        // Neste / Skip
                        Button(action: nextSegmentAction) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            setupWorkout()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { _ in
            guard !isPaused, !isWorkoutComplete, let segment = currentSegment else { return }
            
            switch segment.category {
            case .cardio, .other, .combined:
                if timerValue > 0 {
                    timerValue -= 1
                } else {
                    playSound()
                    nextSegmentAction()
                }
            case .strength:
                break // Ingen timer for reps
            }
        }
    }
    
    // --- LOGIKK ---
    
    func setupWorkout() {
        sortedSegments = routine.segments.sorted { $0.sortIndex < $1.sortIndex }
        if !sortedSegments.isEmpty {
            currentIndex = 0
            resetSegmentState()
        } else {
            isWorkoutComplete = true
        }
    }
    
    func resetSegmentState() {
        guard let segment = currentSegment else { return }
        isPaused = false
        
        switch segment.category {
        case .cardio, .other, .combined:
            timerValue = segment.durationSeconds
        case .strength:
            timerValue = segment.targetReps
        }
    }
    
    func nextSegmentAction() {
        if currentIndex < sortedSegments.count - 1 {
            currentIndex += 1
            resetSegmentState()
        } else {
            playSound(finish: true)
            isWorkoutComplete = true
        }
    }
    
    func previousSegment() {
        if currentIndex > 0 {
            currentIndex -= 1
            resetSegmentState()
        }
    }
    
    func togglePauseOrNext() {
        guard let segment = currentSegment else { return }
        
        if segment.category == .strength {
            nextSegmentAction()
        } else {
            isPaused.toggle()
        }
    }
    
    // --- HJELPERE FOR DISPLAY ---
    
    func progressForSegment(_ segment: CircuitExercise) -> CGFloat {
        switch segment.category {
        case .cardio, .other, .combined:
            return CGFloat(timerValue) / CGFloat(max(segment.durationSeconds, 1))
        case .strength:
            return 1.0
        }
    }
    
    func mainDisplayValue(for segment: CircuitExercise) -> String {
        switch segment.category {
        case .cardio, .other, .combined:
            return formatTime(timerValue)
        case .strength:
            return "\(segment.targetReps)"
        }
    }
    
    func subLabel(for segment: CircuitExercise) -> String {
        switch segment.category {
        case .cardio, .other, .combined:
            return "gjenstår"
        case .strength:
            return "repetisjoner"
        }
    }
    
    func actionIconName(for segment: CircuitExercise) -> String {
        if segment.category == .strength {
            return "checkmark"
        } else {
            return isPaused ? "play.fill" : "pause.fill"
        }
    }
    
    func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)"
    }
    
    func playSound(finish: Bool = false) {
        let soundID: SystemSoundID = finish ? 1022 : 1005
        AudioServicesPlaySystemSound(soundID)
    }
}

// --- FULLFØRT VIEW ---

struct WorkoutCompletedView: View {
    let routineName: String
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.yellow)
            
            Text("Godt jobbet!")
                .font(.largeTitle)
                .bold()
            
            Text("Du har fullført \(routineName).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button(action: onDismiss) {
                Text("Avslutt")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
}
