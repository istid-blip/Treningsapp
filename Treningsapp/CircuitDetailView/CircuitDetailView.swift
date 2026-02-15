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
    @State private var activeDrawer: DrawerState? = nil
    @State private var activePicker: PickerState? = nil
    
    // Styrer visning i tidsskuffen (Stoppeklokke vs Linjal)
    @State private var showStopwatchMode = true
    
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
                                                markSegmentAsVisited(segment)
                                                // Hvis vi åpner et nytt segment manuelt, sjekk om vi skal stoppe andre timere
                                                if !stopwatchManager.isRunning(segment) {
                                                    stopwatchManager.stop()
                                                }
                                                activeDrawer = .editSegment(segment)
                                            }
                                        )
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
                .disabled(activeDrawer != nil || activePicker != nil)
                .ignoresSafeArea(.keyboard)
                
                // --- DIMMING ---
                if activeDrawer != nil || activePicker != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeAllPanels() }
                        .transition(.opacity)
                        .zIndex(10)
                }
                
                // --- HOVEDSKUFF (Add/Edit) ---
                if let drawerState = activeDrawer {
                    let availableHeight = (activePicker != nil)
                    ? (geometry.size.height - pickerHeight)
                    : (geometry.size.height + 60)
                    
                    DrawerView(theme: currentTheme, edge: .top, maxHeight: availableHeight) {
                        switch drawerState {
                        case .editSegment(let segment):
                            AddSegmentView(
                                routine: routine,
                                segmentToEdit: segment,
                                currentActiveField: activePicker?.title,
                                onDismiss: { closeAllPanels() },
                                onRequestPicker: { title, binding, range, step in
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    
                                    let isTime = title.lowercased().contains("tid") || title.lowercased().contains("sek")
                                    showStopwatchMode = isTime
                                    
                                    withAnimation(.snappy) {
                                        activePicker = PickerState(title: title, binding: binding, range: range, step: step)
                                    }
                                },
                                onTyping: {
                                    // Ved typing: Skjul picker, men la timer fortsette i bakgrunnen
                                    withAnimation(.snappy) { activePicker = nil }
                                },
                                onSwitchSegment: { newSegment in
                                    // Krav: Stopp klokken når vi bytter segment
                                    stopwatchManager.stop()
                                    
                                    markSegmentAsVisited(newSegment)
                                    activeDrawer = .editSegment(newSegment)
                                    
                                    if activePicker?.isTimePicker == true && !isSessionStarted {
                                        newSegment.durationSeconds = 0
                                    }
                                }
                            )
                        }
                    }
                    .zIndex(11)
                    .ignoresSafeArea(.all, edges: .top)
                }
                
                // --- PICKER / STOPWATCH SKUFF ---
                if let pickerState = activePicker {
                    DrawerView(theme: currentTheme, edge: .bottom, maxHeight: pickerHeight) {
                        ZStack(alignment: .bottomTrailing) {
                            VStack {
                                Spacer()
                                if pickerState.isTimePicker && showStopwatchMode {
                                    
                                    // Sjekk context for å koble til manager
                                    if case .editSegment(let segment) = activeDrawer {
                                        StopwatchView(
                                            bindingTime: pickerState.binding,
                                            allowResuming: isSessionStarted,
                                            segment: segment,
                                            manager: stopwatchManager
                                        )
                                        .id(pickerState.id)
                                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    } else {
                                        // Fallback
                                        StopwatchView(bindingTime: pickerState.binding, allowResuming: isSessionStarted)
                                    }
                                    
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
                activeDrawer = .editSegment(firstSegment)
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
            activeDrawer = .editSegment(newSegment)
        }
    }
    
    private func closeAllPanels() {
        withAnimation(.snappy) {
            activePicker = nil
            activeDrawer = nil
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            refreshUILoad()
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
