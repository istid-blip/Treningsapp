import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// ... (DrawerState og PickerState er uendret) ...
enum DrawerState: Identifiable {
    case editSegment(CircuitExercise)
    var id: String {
        switch self {
        case .editSegment(let segment): return "edit-\(segment.id)"
        }
    }
}

struct PickerState: Identifiable {
    let id = UUID()
    let title: String
    let binding: Binding<Int>
    let range: ClosedRange<Int>
    let step: Int
}

struct CircuitDetailView: View {
    @Bindable var routine: CircuitRoutine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    // UI States
    @State private var draggingSegment: CircuitExercise?
    @State private var activeDrawer: DrawerState? = nil
    @State private var activePicker: PickerState? = nil
    
    @State private var uiSegments: [CircuitExercise] = []
    @State private var showLogConfirmation = false // Ny: Bekreftelse
    
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    let currentTheme: AppTheme = .standard
    let pickerHeight: CGFloat = 320
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                
                // --- BAKGRUNN ---
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        
                        // 1. EGEN HEADER (Uendret)
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.left").bold()
                                    Text("Tilbake")
                                }
                                .foregroundStyle(Color.blue)
                            }
                            Spacer()
                            TextField("Navn på økt", text: $routine.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .submitLabel(.done)
                            Spacer()
                            Color.clear.frame(width: 60, height: 44)
                        }
                        .padding(.horizontal)
                        .frame(height: 50)
                        .background(Color(.systemBackground))
                        .zIndex(1)
                        
                        // 2. HOVEDINNHOLD
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                LazyVGrid(columns: columns, spacing: 24) {
                                    ForEach(Array(uiSegments.enumerated()), id: \.element.id) { index, segment in
                                        DraggableSegmentView(
                                            segment: segment,
                                            isLast: index == uiSegments.count - 1,
                                            theme: currentTheme,
                                            draggingSegment: $draggingSegment,
                                            onEdit: { activeDrawer = .editSegment(segment) },
                                            onEditValue: { openPickerFor(segment: segment) }
                                        )
                                        .onDrop(of: [.text], delegate: GridDropDelegate(
                                            item: segment,
                                            items: $uiSegments,
                                            draggingItem: $draggingSegment,
                                            onSave: saveSortOrder
                                        ))
                                    }
                                    
                                    // LEGG TIL KNAPP
                                    HStack(spacing: 8) {
                                        Button(action: {
                                            let nextNumber = routine.segments.count + 1
                                            let autoName = "Segment \(nextNumber)"
                                            
                                            let newSegment = CircuitExercise(
                                                name: autoName,
                                                durationSeconds: 45,
                                                targetReps: 10,
                                                category: .strength,
                                                note: "",
                                                sortIndex: routine.segments.count
                                            )
                                            
                                            modelContext.insert(newSegment)
                                            routine.segments.append(newSegment)
                                            
                                            withAnimation(.snappy) {
                                                activeDrawer = .editSegment(newSegment)
                                            }
                                        }) {
                                            TreningsKort(tittel: "Legg til", ikon: "plus", bakgrunnsfarge: Color(.systemGray6), tekstFarge: .blue)
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(Color.blue.opacity(0.5)))
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .aspectRatio(1.0, contentMode: .fit)
                                        Color.clear.frame(width: 20)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 120)
                                .padding(.top, 20)
                            }
                        }
                    }
                    
                    // --- NY LOGG KNAPP (Erstatter Start Trening) ---
                    if !routine.segments.isEmpty {
                        Button(action: logWorkout) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("LOGG ØKT")
                            }
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green) // Grønn for fullført/logg
                            .cornerRadius(12)
                            .padding()
                            .shadow(radius: 5)
                        }
                    }
                }
                .disabled(activeDrawer != nil || activePicker != nil)
                
                // --- DIMMING ---
                if activeDrawer != nil || activePicker != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeAllPanels() }
                        .transition(.opacity)
                        .zIndex(10)
                }
                
                // --- HOVEDSKUFF ---
                if let drawerState = activeDrawer {
                    let availableHeight = activePicker != nil
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
                                    withAnimation(.snappy) {
                                        activePicker = PickerState(title: title, binding: binding, range: range, step: step)
                                    }
                                },
                                onTyping: {
                                    withAnimation(.snappy) {
                                        activePicker = nil
                                    }
                                }
                            )
                        }
                    }
                    .zIndex(11)
                    .ignoresSafeArea(.all, edges: .top)
                }
                
                // --- PICKER SKUFF ---
                if let pickerState = activePicker {
                    DrawerView(theme: currentTheme, edge: .bottom, maxHeight: pickerHeight) {
                        VStack(spacing: 15) {
                            Text(pickerState.title)
                                .font(.headline).padding(.top, 10)
                            
                            Picker("", selection: pickerState.binding) {
                                ForEach(Array(stride(from: pickerState.range.lowerBound, through: pickerState.range.upperBound, by: pickerState.step)), id: \.self) { value in
                                    Text("\(value)").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 150)
                            
                            Button(action: {
                                withAnimation(.snappy) { activePicker = nil }
                            }) {
                                Text("Ferdig")
                                    .font(.headline).frame(maxWidth: .infinity).padding().background(Color.blue).foregroundStyle(Color.white).cornerRadius(12)
                            }
                        }
                    }
                    .zIndex(12)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refreshUILoad() }
        .alert("Økt logget!", isPresented: $showLogConfirmation) {
            Button("OK", role: .cancel) { dismiss() } // Går tilbake til forsiden etter logging
        } message: {
            Text("Godt jobbet! Økten ligger nå i historikken.")
        }
    }
    
    // --- FUNKSJONER ---
    
    // NY FUNKSJON: KOPIERER TIL HISTORIKK
    // NY FUNKSJON: KOPIERER TIL HISTORIKK MED RÅDATA
        private func logWorkout() {
            // 1. Lag en ny logg-oppføring
            let log = WorkoutLog(routineName: routine.name, date: Date())
            
            // 2. Kopier hver øvelse (Snapshot)
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
            
            // 3. Lagre
            modelContext.insert(log)
            try? modelContext.save()
            
            // 4. Vis bekreftelse
            showLogConfirmation = true
        }
    
    private func closeAllPanels() {
        withAnimation(.snappy) {
            activePicker = nil
            activeDrawer = nil
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshUILoad() }
    }
    
    private func openPickerFor(segment: CircuitExercise) {
        if segment.category == .cardio || segment.category == .other {
            activePicker = PickerState(title: "Endre tid (sek)", binding: Binding(get: { segment.durationSeconds }, set: { segment.durationSeconds = $0 }), range: 5...600, step: 5)
        } else {
            activePicker = PickerState(title: "Endre reps", binding: Binding(get: { segment.targetReps }, set: { segment.targetReps = $0 }), range: 1...100, step: 1)
        }
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

// ... (Resten av filen: DraggableSegmentView, DrawerView, GridDropDelegate, ScaleButtonStyle, Helpers er uendret) ...
// Du trenger ikke lime inn DraggableSegmentView etc på nytt hvis du beholder det som var under "body".
// Men husk at 'segmentDescription' funksjonen MÅ være der for at logWorkout skal fungere.
// --- DRAGGABLE VIEW COMPONENT ---

struct DraggableSegmentView: View {
    var segment: CircuitExercise
    var isLast: Bool
    var theme: AppTheme
    @Binding var draggingSegment: CircuitExercise?
    var onEdit: () -> Void
    var onEditValue: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // RETTET: Bruker Color.primary eksplisitt
                TreningsKort(tittel: segment.name, undertittel: segmentDescription(for: segment), ikon: iconForSegment(segment), bakgrunnsfarge: theme.color(for: segment.category), tekstFarge: segment.category == .other ? Color.primary : theme.textColor)
                    .onTapGesture { onEdit() }
                    .aspectRatio(1.0, contentMode: .fit)
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                    .onDrag { self.draggingSegment = segment; return NSItemProvider(object: String(describing: segment.persistentModelID) as NSString) }
                
                Button(action: onEditValue) {
                    ZStack { Circle().fill(Color.white).shadow(radius: 2); Text("\(valueToDisplay())").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.black) }
                        .frame(width: 28, height: 28)
                }
                .offset(x: 8, y: -8)
            }
            .zIndex(1)
            Image(systemName: theme.arrowIcon).font(.title3).fontWeight(.bold).foregroundStyle(theme.arrowColor).frame(width: 20).opacity(isLast ? 0 : 1)
        }
    }
    
    func valueToDisplay() -> Int {
        if segment.category == .cardio || segment.category == .other {
            return segment.durationSeconds
        } else {
            return segment.targetReps
        }
    }
}

// --- GENERISK SKUFFER ---
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
                .background(theme.drawerBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: theme.drawerCornerRadius))
                .shadow(color: theme.drawerShadowColor, radius: 20, x: 0, y: edge == .top ? 10 : -10)
                .padding(.horizontal, 16)
                .padding(.top, edge == .top ? 10 : 0)
                .padding(.bottom, edge == .bottom ? 40 : 0)
                .frame(maxHeight: maxHeight)
                .animation(.snappy, value: maxHeight)
            if edge == .top { Spacer() }
        }
        .transition(.move(edge: edge == .top ? .top : .bottom))
    }
}

// --- HJELPEFUNKSJONER ---

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
    switch segment.category {
    case .strength:
        let weightInfo = segment.weight > 0 ? " @ \(Int(segment.weight))kg" : ""
        return "\(segment.targetReps) reps\(weightInfo)"
    case .cardio:
        let distInfo = segment.distance > 0 ? " (\(Int(segment.distance)) m)" : ""
        return "\(segment.durationSeconds) sek\(distInfo)"
    case .other:
        return "\(segment.durationSeconds) sek" // Viser bare tid, navnet forklarer hva det er
    case .combined:
        return "\(segment.targetReps) reps / \(segment.durationSeconds) sek"
    }
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    switch segment.category { case .strength: return "dumbbell.fill"; case .cardio: return "figure.run"; case .combined: return "figure.strengthtraining.functional"; case .other: return "timer" }
}
