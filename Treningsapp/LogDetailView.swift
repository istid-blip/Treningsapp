import SwiftUI
import SwiftData

struct LogDetailView: View {
    let log: WorkoutLog
    @Environment(\.dismiss) var dismiss
    
    // --- NAVIGASJON OG ANIMASJON (Erstatter activeDrawer) ---
    @Namespace private var logAnimation
    @State private var entryToNavigate: LoggedExercise? = nil
    // --------------------------------------------------------
    
    @State private var activePicker: PickerState? = nil
    @State private var showStopwatchMode = true
    
    // --- ENDRING START: Ny state for å styre statistikk-visning ---
    @State private var statsExercise: LoggedExercise? = nil
    // --- ENDRING SLUTT ---
    
    let currentTheme: AppTheme = .standard
    let pickerHeight: CGFloat = 280
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                
                VStack(spacing: 0) {
                    
                    // --- HEADER (Uendret) ---
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left").bold()
                                Text("Tilbake")
                            }
                            .foregroundStyle(Color.blue)
                        }
                        Spacer()
                        Text("Oppsummering av \(log.routineName)")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Spacer()
                        Color.clear.frame(width: 75, height: 44)
                    }
                    .padding(.horizontal)
                    .frame(height: 50)
                    .background(Color(.systemBackground))
                    .zIndex(1)
                    
                    // --- LISTE ---
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(log.routineName).font(.title).bold()
                                    Spacer()
                                    VStack {
                                        Image(systemName: "calendar").font(.title2).foregroundStyle(.blue)
                                        Text(log.date.formatted(.dateTime.day().month())).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                if log.totalDuration > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock").foregroundStyle(.gray)
                                        Text("Total tid:").foregroundStyle(.secondary)
                                        Text(formatTid(log.totalDuration)).bold().foregroundStyle(.blue)
                                    }
                                    .font(.subheadline)
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        
                        Section("Gjennomførte øvelser") {
                            // --- ENDRING START: Ny rad-design med to knapper ---
                            ForEach(log.exercises.sorted(by: { $0.sortIndex < $1.sortIndex })) { exercise in
                                VStack(alignment: .leading, spacing: 8) {
                                    
                                    // 1. INFO DEL (Navn, kategori, detaljer)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(exercise.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text(exercise.category.rawValue)
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(AppTheme.standard.color(for: exercise.category).opacity(0.2))
                                                .foregroundStyle(AppTheme.standard.color(for: exercise.category))
                                                .clipShape(Capsule())
                                        }
                                        
                                        // Detaljer (reps, vekt osv) med overstreking bevart
                                        HStack {
                                            detailView(for: exercise)
                                            
                                            if exercise.hasChanges {
                                                Spacer()
                                                Image(systemName: "pencil")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                        
                                        if !exercise.note.isEmpty {
                                            Text(exercise.note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .italic()
                                        }
                                    }
                                    
                                    // 2. KNAPPE-RAD (Statistikk & Juster)
                                    HStack(spacing: 12) {
                                        // Knapp 1: Statistikk
                                        Button(action: {
                                            withAnimation(.snappy) {
                                                statsExercise = exercise
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "chart.xyaxis.line")
                                                Text("Se fremgang")
                                            }
                                            .font(.caption).fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundStyle(.blue)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        // NYTT: Knytter knappen til zoom-animasjonen
                                        .matchedTransitionSource(id: "stats-\(exercise.persistentModelID.hashValue)", in: logAnimation)
                                        
                                        // Knapp 2: Juster / Rediger
                                        Button(action: {
                                            // OPPDATERT: Sett navigasjon i stedet for skuff
                                            withAnimation(.snappy) {
                                                entryToNavigate = exercise
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "slider.horizontal.3")
                                                Text("Juster")
                                            }
                                            .font(.caption).fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.orange.opacity(0.1))
                                            .foregroundStyle(.orange)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        // OPPDATERT: Knytt zoom-animasjonen til knappen
                                        .matchedTransitionSource(id: exercise.persistentModelID, in: logAnimation)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            // --- ENDRING SLUTT ---
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // --- ENDRING START: Presenterer statistikk-arket ---
        // --- OPPDATERT: Presenterer statistikk med zoom-effekt ---
        .navigationDestination(item: $statsExercise) { exercise in
            ExerciseStatsView(exerciseName: exercise.name, category: exercise.category)
                .navigationTransition(.zoom(sourceID: "stats-\(exercise.persistentModelID.hashValue)", in: logAnimation))
        }
        // --- ENDRING SLUTT ---
        
        // --- NYTT: NAVIGASJONSDESTINASJON ---
        .navigationDestination(item: $entryToNavigate) { entry in
            LogEditorScreen(
                log: log,
                currentEntry: entry,
                theme: currentTheme,
                onSwitchEntry: { newEntry in
                    entryToNavigate = newEntry
                }
            )
            .navigationTransition(.zoom(sourceID: entry.persistentModelID, in: logAnimation))
        }
    }
    
    // --- HJELPEFUNKSJONER (Uendret) ---
    
    @ViewBuilder
    func detailView(for exercise: LoggedExercise) -> some View {
        HStack(spacing: 8) {
            if exercise.targetReps > 0 || exercise.originalReps != nil {
                buildChangeText(original: exercise.originalReps, current: exercise.targetReps, unit: "reps")
            }
            if exercise.weight > 0 || exercise.originalWeight != nil {
                buildChangeText(original: exercise.originalWeight.map { Int($0) }, current: Int(exercise.weight), unit: "kg")
            }
            if exercise.durationSeconds > 0 || exercise.originalDuration != nil {
                if let orig = exercise.originalDuration {
                    Text(formatTid(orig)).strikethrough().foregroundStyle(.secondary)
                    Text(formatTid(exercise.durationSeconds)).foregroundStyle(.blue)
                } else {
                    Text(formatTid(exercise.durationSeconds)).foregroundStyle(.secondary)
                }
            }
            if exercise.distance > 0 || exercise.originalDistance != nil {
                buildChangeText(original: exercise.originalDistance.map { Int($0) }, current: Int(exercise.distance), unit: "m")
            }
        }
        .font(.subheadline)
    }
    
    @ViewBuilder
    func buildChangeText(original: Int?, current: Int, unit: String) -> some View {
        HStack(spacing: 4) {
            if let orig = original, orig != current {
                Text("\(orig)").strikethrough().foregroundStyle(.secondary)
                Text("\(current)").bold().foregroundStyle(.blue)
            } else {
                Text("\(current)").foregroundStyle(.secondary)
            }
            Text(unit).foregroundStyle(.secondary)
        }
    }
}


// --- NYTT: WRAPPER-VIEW FOR Å HÅNDTERE SKUFFEN I BUNNEN ---
struct LogEditorScreen: View {
    var log: WorkoutLog
    @State var currentEntry: LoggedExercise
    var theme: AppTheme
    var onSwitchEntry: (LoggedExercise) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var activePicker: PickerState? = nil
    @State private var showStopwatchMode = true
    let pickerHeight: CGFloat = 280
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toppmeny
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").bold()
                            Text("Tilbake")
                        }
                        .foregroundStyle(Color.blue)
                    }
                    Spacer()
                    Text("Juster logg")
                        .font(.headline)
                    Spacer()
                    if activePicker != nil {
                        Button("Ferdig") {
                            withAnimation(.snappy) { activePicker = nil }
                        }
                        .foregroundStyle(.blue)
                        .bold()
                    } else {
                        Color.clear.frame(width: 80, height: 44)
                    }
                }
                .padding(.horizontal)
                .frame(height: 50)
                .background(Color(.systemBackground))
                .zIndex(20)
                
                // Redigeringsskjemaet
                AddSegmentView(
                    routine: nil,
                    segmentToEdit: nil,
                    log: log,
                    logEntryToEdit: currentEntry,
                    currentActiveField: activePicker?.title,
                    onDismiss: { dismiss() },
                    onRequestPicker: { title, binding, range, step in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        let isTime = title.lowercased().contains("tid") || title.lowercased().contains("sek")
                        showStopwatchMode = isTime
                        withAnimation(.snappy) {
                            activePicker = PickerState(title: title, binding: binding, range: range, step: step)
                        }
                    },
                    onTyping: {
                        withAnimation(.snappy) { activePicker = nil }
                    },
                    onSwitchSegment: nil,
                    onSwitchLogEntry: { newEntry in
                        currentEntry = newEntry
                        onSwitchEntry(newEntry)
                    }
                )
                .padding(.bottom, activePicker != nil ? pickerHeight : 0)
            }
            
            // Dimming bak skuffen
            if activePicker != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .padding(.top, 50)
                    .onTapGesture {
                        withAnimation(.snappy) { activePicker = nil }
                    }
                    .zIndex(10)
            }
            
            // Bunnskuff
            if let pickerState = activePicker {
                DrawerView(theme: theme, edge: .bottom, maxHeight: pickerHeight) {
                    ZStack(alignment: .bottomTrailing) {
                        VStack {
                            Spacer()
                            if pickerState.isTimePicker && showStopwatchMode {
                                StopwatchView(bindingTime: pickerState.binding)
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                            } else {
                                VerticalRuler(value: pickerState.binding, range: pickerState.range, step: pickerState.step)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .animation(.snappy(duration: 0.3), value: showStopwatchMode)
                        
                        if pickerState.isTimePicker {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showStopwatchMode.toggle()
                                }
                            }) {
                                ZStack {
                                    Circle().fill(Color(.secondarySystemFill)).shadow(radius: 2)
                                    Image(systemName: showStopwatchMode ? "ruler" : "stopwatch")
                                        .font(.title2).foregroundStyle(.primary)
                                }
                                .frame(width: 50, height: 50)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                .zIndex(12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
