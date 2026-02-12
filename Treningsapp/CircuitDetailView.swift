import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import Combine

// UI States
enum DrawerState: Identifiable {
    case editSegment(CircuitExercise)
    var id: String {
        switch self {
        case .editSegment(let segment): return "edit-\(segment.persistentModelID)"
        }
    }
}

struct PickerState: Identifiable {
    let id = UUID()
    let title: String
    let binding: Binding<Int>
    let range: ClosedRange<Int>
    let step: Int
    
    var isTimePicker: Bool {
        title.lowercased().contains("tid") || title.lowercased().contains("sek")
    }
}

struct CircuitDetailView: View {
    @Bindable var routine: CircuitRoutine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
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
                        
                        // 2. MODULÆR ACTION-KNAPP
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
                        
                        // 3. HOVEDINNHOLD
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
                                    withAnimation(.snappy) { activePicker = nil }
                                },
                                onSwitchSegment: { newSegment in
                                    markSegmentAsVisited(newSegment)
                                    activeDrawer = .editSegment(newSegment)
                                    
                                    // Hvis vi allerede har en picker/stoppeklokke åpen, bytt til den nye øvelsen
                                    if let current = activePicker {
                                        // Finn ut hva vi skal binde mot (Tid, reps, etc.)
                                        var newBinding: Binding<Int>?
                                        
                                        if current.isTimePicker {
                                            newSegment.durationSeconds = 0 // Nullstiller data-verdien
                                            newBinding = Binding(get: { newSegment.durationSeconds }, set: { newSegment.durationSeconds = $0 })
                                        } else if current.title.contains("reps") {
                                            newBinding = Binding(get: { newSegment.targetReps }, set: { newSegment.targetReps = $0 })
                                        } else if current.title.contains("Vekt") || current.title.contains("kg") {
                                            newBinding = Binding(get: { Int(newSegment.weight) }, set: { newSegment.weight = Double($0) })
                                        } else if current.title.contains("Meter") {
                                            newBinding = Binding(get: { Int(newSegment.distance) }, set: { newSegment.distance = Double($0) })
                                        }
                                        
                                        // Opprett en NY PickerState. Dette genererer en ny unik ID som trigger nullstillingen!
                                        if let binding = newBinding {
                                            withAnimation(.snappy) {
                                                activePicker = PickerState(
                                                    title: current.title,
                                                    binding: binding,
                                                    range: current.range,
                                                    step: current.step
                                                )
                                            }
                                        } else {
                                            activePicker = nil // Lukk hvis kategorien ikke passer lenger
                                        }
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
                                    StopwatchView(bindingTime: pickerState.binding)
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshUILoad()
            if originalName.isEmpty { originalName = routine.name }
            
            // --- ENDRING: Reset tid ved åpning av økt ---
            if !isSessionStarted {
                for segment in routine.segments {
                    segment.durationSeconds = 0
                }
            }
            // ------------------------------------------
        }
        .alert("Ufullstendig økt?", isPresented: $showIncompleteAlert) {
            Button("Logg likevel", role: .none) {
                performLogging()
            }
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
        let startTime = sessionStartTime ?? Date()
        let elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        
        let log = WorkoutLog(routineName: routine.name, date: Date(), totalDuration: elapsedSeconds)
        
        for segment in uiSegments {
            let loggedExercise = LoggedExercise(
                name: segment.name,
                categoryRawValue: segment.category.rawValue,
                duration: segment.durationSeconds,
                reps: segment.targetReps,
                weight: segment.weight,
                distance: segment.distance,
                note: segment.note
            )
            log.exercises.append(loggedExercise)
        }
        modelContext.insert(log)
        
        // --- ENDRING: Reset tid og status etter logging ---
        for segment in routine.segments {
            segment.durationSeconds = 0
        }
        
        // Reset status for økten
        isSessionStarted = false
        sessionStartTime = nil
        completedSegmentIds.removeAll()
        // ------------------------------------------------
        
        try? modelContext.save()
        showLogConfirmation = true
    }
    
    func addSegment() {
        let lastSegment = routine.segments.sorted { $0.sortIndex < $1.sortIndex }.last
        let nextNumber = routine.segments.count + 1
        let autoName = "Øvelse \(nextNumber)"
        
        let newSegment = CircuitExercise(
            name: autoName,
            durationSeconds: 0, // Starter på 0
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshUILoad() }
    }
    
    private func refreshUILoad() {
        let uniqueSegments = Set(routine.segments)
        self.uiSegments = Array(uniqueSegments).sorted { $0.sortIndex < $1.sortIndex }
    }
    
    private func saveSortOrder() {
        for (index, segment) in uiSegments.enumerated() { segment.sortIndex = index }
        try? modelContext.save()
    }
}

// --- HJELPEKOMPONENTER ---
// (Disse er uendret, men inkludert for å være sikker på at alt fungerer sammen)

struct StopwatchView: View {
    @Binding var bindingTime: Int
    @State private var elapsedTime: Double = 0.0
    @State private var isRunning = false
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
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
                            .contentTransition(.numericText(value: elapsedTime))
                        
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 190, height: 190)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        // Starter alltid på 0 når viewet vises for å ta ny tid
        .onAppear { elapsedTime = 0.0 }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            elapsedTime += 0.1
            if Int(elapsedTime) != bindingTime { bindingTime = Int(elapsedTime) }
        }
        .onDisappear { isRunning = false }
    }
    
    func toggleStopwatch() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isRunning.toggle() }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func formatDetailedTime(_ totalSeconds: Double) -> String {
        let seconds = Int(totalSeconds)
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct DraggableSegmentView: View {
    var segment: CircuitExercise
    var isLast: Bool
    var theme: AppTheme
    @Binding var draggingSegment: CircuitExercise?
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TreningsKort(
                tittel: segment.name,
                undertittel: segmentDescription(for: segment),
                ikon: iconForSegment(segment),
                bakgrunnsfarge: theme.color(for: segment.category),
                tekstFarge: segment.category == .other ? Color.primary : theme.textColor
            )
            .onTapGesture { onEdit() }
            .aspectRatio(1.0, contentMode: .fit)
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
            .onDrag { self.draggingSegment = segment; return NSItemProvider(object: String(describing: segment.persistentModelID) as NSString) }
            
            Image(systemName: theme.arrowIcon)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(theme.arrowColor)
                .frame(width: 20)
                .opacity(isLast ? 0 : 1)
        }
    }
}

struct DrawerView<Content: View>: View {
    let theme: AppTheme
    let edge: VerticalEdge
    let maxHeight: CGFloat
    let content: Content
    
    init(theme: AppTheme, edge: VerticalEdge = .top, maxHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.edge = edge
        if let max = maxHeight {
            self.maxHeight = max
        } else {
            self.maxHeight = (edge == .bottom ? 320 : 550)
        }
        self.content = content()
    }
    
    var body: some View {
        VStack {
            if edge == .bottom { Spacer() }
            content
                .background(theme.drawerBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.drawerCornerRadius))
                .shadow(color: theme.drawerShadowColor, radius: 20, x: 0, y: edge == .top ? 10 : -10)
                .padding(.horizontal, 16)
                .padding(.top, edge == .top ? 100 : 0)
                .padding(.bottom, edge == .bottom ? 40 : 0)
                .frame(maxHeight: maxHeight)
                .animation(.snappy, value: maxHeight)
            if edge == .top { Spacer() }
        }
        .transition(.move(edge: edge == .top ? .top : .bottom))
    }
}

struct GridDropDelegate: DropDelegate {
    let item: CircuitExercise
    @Binding var items: [CircuitExercise]
    @Binding var draggingItem: CircuitExercise?
    var onSave: () -> Void
    
    func dropUpdated(info: DropInfo) -> DropProposal? { return DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { draggingItem = nil; onSave(); return true }
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        if draggingItem.id != item.id {
            guard let fromIndex = items.firstIndex(of: draggingItem), let toIndex = items.firstIndex(of: item) else { return }
            withAnimation(.snappy) { items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex) }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1.0).animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

func segmentDescription(for segment: CircuitExercise) -> String {
    var linjer: [String] = []
    
    switch segment.category {
    case .strength:
        if segment.targetReps > 0 {
            if segment.weight > 0 {
                linjer.append("\(segment.targetReps) x \(Int(segment.weight)) kg")
            } else {
                linjer.append("\(segment.targetReps) reps")
            }
        } else if segment.weight > 0 {
            linjer.append("\(Int(segment.weight)) kg")
        }
    case .cardio:
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
        if segment.distance > 0 { linjer.append("\(Int(segment.distance)) m") }
    case .combined:
        if segment.targetReps > 0 { linjer.append("\(segment.targetReps) reps") }
        if segment.weight > 0 { linjer.append("\(Int(segment.weight)) kg") }
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
        if segment.distance > 0 { linjer.append("\(Int(segment.distance)) m") }
    case .other:
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
    }
    return linjer.isEmpty ? "-" : linjer.joined(separator: "\n")
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    switch segment.category { case .strength: return "dumbbell.fill"; case .cardio: return "figure.run"; case .combined: return "figure.strengthtraining.functional"; case .other: return "timer" }
}

struct VerticalRuler: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    
    private let itemHeight: CGFloat = 40
    private let rulerHeight: CGFloat = 200
    
    @State private var dragOffset: CGFloat = 0
    @State private var initialDragValue: Int? = nil
    let feedbackGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        GeometryReader { geometry in
            let midY = geometry.size.height / 2
            let centerX = geometry.size.width / 2
            
            ZStack {
                Color.black.opacity(0.001).contentShape(Rectangle())
                let numLinesHalf = Int(ceil(rulerHeight / itemHeight / 2)) + 1
                
                ForEach(-numLinesHalf...numLinesHalf, id: \.self) { i in
                    let num = value + (i * step)
                    if range.contains(num) {
                        let lineY = midY + CGFloat(i) * itemHeight + dragOffset
                        let isMajor = num % (step * 5) == 0
                        let dist = abs(lineY - midY)
                        let opacity = max(0, 1 - (dist / (rulerHeight / 2)))
                        
                        if opacity > 0 {
                            Rectangle()
                                .fill(Color.gray.opacity(isMajor ? 0.5 : 0.3))
                                .frame(width: isMajor ? 80 : 40, height: 2)
                                .position(x: centerX, y: lineY)
                                .opacity(opacity)
                        }
                    }
                }
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 110, height: 4)
                    .cornerRadius(2)
                    .position(x: centerX, y: midY)
                    .allowsHitTesting(false)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if initialDragValue == nil {
                            initialDragValue = value
                            feedbackGenerator.prepare()
                        }
                        let rawTranslation = gesture.translation.height
                        let magnitude = abs(rawTranslation)
                        let boostFactor = 1.0 + (magnitude / 200.0)
                        let effectiveTranslation = rawTranslation * boostFactor
                        let steps = -Int(effectiveTranslation / itemHeight)
                        let remainder = effectiveTranslation.truncatingRemainder(dividingBy: itemHeight)
                        
                        if let startVal = initialDragValue {
                            let calculatedValue = startVal + (steps * step)
                            var newValue = value
                            if calculatedValue < range.lowerBound {
                                newValue = range.lowerBound
                                dragOffset = remainder / 3
                            } else if calculatedValue > range.upperBound {
                                newValue = range.upperBound
                                dragOffset = remainder / 3
                            } else {
                                newValue = calculatedValue
                                dragOffset = remainder
                            }
                            if newValue != value {
                                feedbackGenerator.selectionChanged()
                                value = newValue
                            }
                        }
                    }
                    .onEnded { _ in
                        initialDragValue = nil
                        withAnimation(.snappy(duration: 0.15)) { dragOffset = 0 }
                    }
            )
        }
        .frame(height: rulerHeight)
        .clipped()
    }
}
