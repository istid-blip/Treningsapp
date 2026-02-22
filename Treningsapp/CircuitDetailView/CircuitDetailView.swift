import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CircuitDetailView: View {
    @Bindable var routine: CircuitRoutine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    // --- STOPPEKLOKKE MANAGER ---
    // Holder styr på aktiv timer på tvers av views
    @StateObject private var stopwatchManager = StopwatchManager()
    
    // UI States
    @State private var draggingSegment: CircuitExercise?
    
    @Namespace private var segmentAnimation
    @State private var segmentToNavigate: CircuitExercise?
    
    @State private var uiSegments: [CircuitExercise] = []
    @State private var showLogConfirmation = false
    @State private var showIncompleteAlert = false
    @State private var originalName: String = ""
    
    // LOGIKK FOR ØKT-STATUS
    @State private var sessionStartTime: Date? = nil
    @State private var isSessionStarted = false
    @State private var completedSegmentIds: Set<PersistentIdentifier> = []
    
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    let currentTheme: AppTheme = .standard
    let pickerHeight: CGFloat = 280
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                
                // --- BAKGRUNN ---
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        
                        // 1. HEADER
                        HStack {
                            Button(action: {
                                if routine.segments.isEmpty && routine.name == originalName {
                                    modelContext.delete(routine)
                                }
                                stopwatchManager.stop()
                                dismiss()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.left").bold()
                                    Text("Tilbake")
                                }
                                .foregroundStyle(Color.blue)
                            }
                            Spacer()
                            TextField("Navn på økt", text: $routine.name)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .submitLabel(.done)
                            Spacer()
                            Color.clear.frame(width: 60, height: 44)
                        }
                        .padding(.horizontal)
                        .frame(height: 50)
                        .background(Color(.systemBackground))
                        .zIndex(1)
                        
                        // 2. ACTION-KNAPP (Start/Logg)
                        if !routine.segments.isEmpty {
                            Button(action: handleMainButtonAction) {
                                HStack {
                                    Image(systemName: isSessionStarted ? "checkmark.circle.fill" : "play.circle.fill")
                                    Text(isSessionStarted ? "LOGG ØKT" : "START ØKT")
                                }
                                .font(.headline)
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isSessionStarted ? Color.green : Color.blue)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                        
                        // 3. HOVEDINNHOLD (Grid)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                LazyVGrid(columns: columns, spacing: 24) {
                                    ForEach(Array(uiSegments.enumerated()), id: \.element.id) { index, segment in
                                        DraggableSegmentView(
                                            segment: segment,
                                            isLast: index == uiSegments.count - 1,
                                            theme: currentTheme,
                                            draggingSegment: $draggingSegment,
                                            onEdit: {
                                                // 1. Sett destinasjonen for navigering umiddelbart:
                                                segmentToNavigate = segment
                                                
                                                // 2. Forsink andre oppdateringer med 0.1 sek, slik at SwiftUI
                                                // rekker å registrere hvilket kort som skal forstørres:
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    markSegmentAsVisited(segment)
                                                    if !stopwatchManager.isRunning(segment) {
                                                        stopwatchManager.stop()
                                                    }
                                                }
                                            }
                                        )
                                        // 3. LEGG TIL DENNE RETT ETTER DraggableSegmentView:
                                        .matchedTransitionSource(id: segment.persistentModelID, in: segmentAnimation)
                                        .onDrop(of: [.text], delegate: GridDropDelegate(
                                            item: segment,
                                            items: $uiSegments,
                                            draggingItem: $draggingSegment,
                                            onSave: saveSortOrder
                                        ))
                                    }
                                    
                                    // LEGG TIL KNAPP
                                    Button(action: addSegment) {
                                        TreningsKort(tittel: "Legg til", ikon: "plus", bakgrunnsfarge: Color(.systemGray6), tekstFarge: .blue)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(Color.blue.opacity(0.5)))
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .aspectRatio(1.0, contentMode: .fit)
                                    Color.clear.frame(width: 20)
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 120)
                                .padding(.top, 10)
                            }
                        }
                    }
                }
                .ignoresSafeArea(.keyboard)
                
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshUILoad()
            if originalName.isEmpty { originalName = routine.name }
            if !isSessionStarted {
                for segment in routine.segments { segment.durationSeconds = 0 }
            }
        }
        .alert("Ufullstendig økt?", isPresented: $showIncompleteAlert) {
            Button("Logg likevel", role: .none) { performLogging() }
            Button("Avbryt", role: .cancel) { }
        } message: {
            Text("Du har ikke vært gjennom alle øvelsene. Vil du lagre økten nå eller fortsette?")
        }
        .alert("Økt logget!", isPresented: $showLogConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Godt jobbet! Økten ligger nå i historikken.")
        }
        .navigationDestination(item: $segmentToNavigate) { segment in
            SegmentEditorScreen(
                routine: routine,
                currentSegment: segment,
                stopwatchManager: stopwatchManager,
                isSessionStarted: isSessionStarted,
                theme: currentTheme,
                onMarkVisited: { markSegmentAsVisited($0) }
            )
            .navigationTransition(.zoom(sourceID: segment.persistentModelID, in: segmentAnimation))
            .onDisappear { refreshUILoad() }
        }
    }
        
    
    
    
    
    
    
    // --- FUNKSJONER ---
    
    func handleMainButtonAction() {
        if !isSessionStarted {
            startSession()
        } else {
            attemptLogWorkout()
        }
    }
    
    func startSession() {
        sessionStartTime = Date()
        isSessionStarted = true
        
        if let firstSegment = uiSegments.first {
            markSegmentAsVisited(firstSegment)
            withAnimation(.snappy) {
                segmentToNavigate = firstSegment
            }
        }
    }
    
    func attemptLogWorkout() {
        let allVisited = uiSegments.allSatisfy { completedSegmentIds.contains($0.persistentModelID) }
        
        if allVisited {
            performLogging()
        } else {
            showIncompleteAlert = true
        }
    }
    
    func markSegmentAsVisited(_ segment: CircuitExercise) {
        completedSegmentIds.insert(segment.persistentModelID)
    }
    
    func performLogging() {
        stopwatchManager.stop()
        let startTime = sessionStartTime ?? Date()
        let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        
        let log = WorkoutLog(routineName: routine.name, date: Date(), totalDuration: elapsedSeconds)
        
        for (index, segment) in uiSegments.enumerated() {
            let loggedExercise = LoggedExercise(
                name: segment.name,
                categoryRawValue: segment.category.rawValue,
                duration: segment.durationSeconds,
                reps: segment.targetReps,
                weight: segment.weight,
                distance: segment.distance,
                note: segment.note,
                sortIndex: index
            )
            log.exercises.append(loggedExercise)
        }
        
        modelContext.insert(log)
        
        for segment in routine.segments {
            segment.durationSeconds = 0
        }
        
        isSessionStarted = false
        sessionStartTime = nil
        completedSegmentIds.removeAll()
        try? modelContext.save()
        
        showLogConfirmation = true
    }
    
    func addSegment() {
        let lastSegment = routine.segments.sorted { $0.sortIndex < $1.sortIndex }.last
        let nextNumber = routine.segments.count + 1
        let autoName = "Øvelse \(nextNumber)"
        
        let newSegment = CircuitExercise(
            name: autoName,
            durationSeconds: 0,
            targetReps: lastSegment?.targetReps ?? 10,
            weight: lastSegment?.weight ?? 0.0,
            distance: lastSegment?.distance ?? 0.0,
            category: lastSegment?.category ?? .strength,
            note: "",
            sortIndex: routine.segments.count
        )
        
        modelContext.insert(newSegment)
        routine.segments.append(newSegment)
        markSegmentAsVisited(newSegment)
        
        stopwatchManager.stop()
        
        withAnimation(.snappy) {
            segmentToNavigate = newSegment
        }
    }
    
    private func refreshUILoad() {
        let uniqueSegments = Set(routine.segments)
        self.uiSegments = Array(uniqueSegments).sorted { $0.sortIndex < $1.sortIndex }
    }
    
    private func saveSortOrder() {
        for (index, segment) in uiSegments.enumerated() {
            segment.sortIndex = index
        }
        try? modelContext.save()
    }
}
struct SegmentEditorScreen: View {
    var routine: CircuitRoutine
    @State var currentSegment: CircuitExercise
    @ObservedObject var stopwatchManager: StopwatchManager
    var isSessionStarted: Bool
    var theme: AppTheme
    var onMarkVisited: (CircuitExercise) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var activePicker: PickerState? = nil
    @State private var showStopwatchMode = true
    let pickerHeight: CGFloat = 280
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            // Hovedinnholdet
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
                    Text("Rediger øvelse")
                        .font(.headline)
                    Spacer()
                    // Ferdig-knapp for å enkelt lukke skuffen
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
                    routine: routine,
                    segmentToEdit: currentSegment,
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
                    onSwitchSegment: { newSegment in
                        stopwatchManager.stop()
                        onMarkVisited(newSegment)
                        currentSegment = newSegment
                        if activePicker?.isTimePicker == true && !isSessionStarted {
                            newSegment.durationSeconds = 0
                        }
                    }
                )
                // Usynlig padding så innholdet kan scrolle over skuffen
                .padding(.bottom, activePicker != nil ? pickerHeight : 0)
            }
            
            // Dimming bak skuffen
            if activePicker != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .padding(.top, 50) // Starter under toppmenyen
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
            
            // SKUFFEN: Nøyaktig slik den lå originalt
            if let pickerState = activePicker {
                DrawerView(theme: theme, edge: .bottom, maxHeight: pickerHeight) {
                    ZStack(alignment: .bottomTrailing) {
                        VStack {
                            Spacer()
                            if pickerState.isTimePicker && showStopwatchMode {
                                StopwatchView(
                                    bindingTime: pickerState.binding,
                                    allowResuming: isSessionStarted,
                                    segment: currentSegment,
                                    manager: stopwatchManager
                                )
                                .id(pickerState.id)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                            } else {
                                VerticalRuler(
                                    value: pickerState.binding,
                                    range: pickerState.range,
                                    step: pickerState.step
                                )
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
