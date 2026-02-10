import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// UI States
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
    @State private var showLogConfirmation = false
    
    // NY: Husker hva navnet var da vi kom inn
    @State private var originalName: String = ""
    
    // Grid configuration
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    let currentTheme: AppTheme = .standard
    let pickerHeight: CGFloat = 320
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                
                // --- BAKGRUNN ---
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        
                        // 1. HEADER
                        HStack {
                            // NY LOGIKK: Tilbake-knappen
                            Button(action: {
                                // Sjekk: Er økten tom OG har navnet vi startet med?
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
                                            onEdit: { activeDrawer = .editSegment(segment) }
                                          
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
                                                                            Button(action: addSegment) {
                                                                                TreningsKort(tittel: "Legg til", ikon: "plus", bakgrunnsfarge: Color(.systemGray6), tekstFarge: .blue)
                                                                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 2, dash: [5])).foregroundStyle(Color.blue.opacity(0.5)))
                                                                            }
                                                                            .buttonStyle(ScaleButtonStyle())
                                                                            .aspectRatio(1.0, contentMode: .fit)
                                                                            
                                                                            // Usynlig boks for å matche bredden til pilen i de andre kortene (20pt)
                                                                            Color.clear.frame(width: 20)
                                                                        }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 120)
                                .padding(.top, 20)
                            }
                        }
                    }
                    
                    // --- LOGG KNAPP ---
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
                            .background(Color.green)
                            .cornerRadius(12)
                            .padding()
                            .shadow(radius: 5)
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
                                                            // 1. Lukk tastaturet hvis det er åpent
                                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                            
                                                            // 2. Åpne pickeren (skuffen)
                                                            withAnimation(.snappy) {
                                                                activePicker = PickerState(title: title, binding: binding, range: range, step: step)
                                                            }
                                                        },
                                onTyping: {
                                    withAnimation(.snappy) { activePicker = nil }
                                }
                            )
                        }
                    }
                    .zIndex(11)
                    .ignoresSafeArea(.all, edges: .top)
                }
                
                // --- PICKER SKUFF (Ny Vertical Ruler) ---
                                if let pickerState = activePicker {
                                    DrawerView(theme: currentTheme, edge: .bottom, maxHeight: pickerHeight) {
                                        VStack(spacing: 0) {
                                            Text(pickerState.title)
                                                .font(.headline)
                                                .foregroundStyle(.secondary)
                                                .padding(.top, 30)
                                                .padding(.bottom, 10)
                                            
                                            // Den nye linjalen
                                            VerticalRuler(
                                                value: pickerState.binding,
                                                range: pickerState.range,
                                                step: pickerState.step
                                            )
                                            
                                            Spacer()
                                        }
                                    }
                                    .zIndex(12)
                                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            refreshUILoad()
            // Lagre originalnavnet når vi åpner siden
            if originalName.isEmpty {
                originalName = routine.name
            }
        }
        .alert("Økt logget!", isPresented: $showLogConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Godt jobbet! Økten ligger nå i historikken.")
        }
    }
    
    // --- FUNKSJONER ---
    
    func addSegment() {
        let nextNumber = routine.segments.count + 1
        let autoName = "Øvelse \(nextNumber)"
        
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
    }
    
    private func logWorkout() {
        let log = WorkoutLog(routineName: routine.name, date: Date())
        
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
        try? modelContext.save()
        
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

// --- HJELPEKOMPONENTER ---

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
    
    func valueToDisplay() -> Int {
        if segment.category == .cardio || segment.category == .other {
            return segment.durationSeconds
        } else {
            return segment.targetReps
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
    var linjer: [String] = []
    
    switch segment.category {
    case .strength:
        // STYRKE: Vis Reps og Vekt
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
        // KONDISJON: Vis Tid og Avstand (Ignorer reps/vekt selv om det ligger lagret)
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
        if segment.distance > 0 { linjer.append("\(Int(segment.distance)) m") }
        
    case .combined:
        // KOMBINERT: Vis alt som er satt
        if segment.targetReps > 0 { linjer.append("\(segment.targetReps) reps") }
        if segment.weight > 0 { linjer.append("\(Int(segment.weight)) kg") }
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
        if segment.distance > 0 { linjer.append("\(Int(segment.distance)) m") }
        
    case .other:
        // ANNET: Vis primært tid
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
    }
    
    // Hvis ingen info er satt, vis en bindestrek
    return linjer.isEmpty ? "-" : linjer.joined(separator: "\n")
}

// Hjelpefunksjon for tid
func formatTid(_ sekunder: Int) -> String {
    if sekunder >= 60 {
        let min = sekunder / 60
        let sek = sekunder % 60
        return String(format: "%d:%02d min", min, sek)
    } else {
        return "\(sekunder) sek"
    }
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    switch segment.category { case .strength: return "dumbbell.fill"; case .cardio: return "figure.run"; case .combined: return "figure.strengthtraining.functional"; case .other: return "timer" }
}
struct VerticalRuler: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Luft over første tall (halvparten av ruler-høyden)
                Spacer().frame(height: 125)
                
                ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: step)), id: \.self) { num in
                    HStack {
                        // Tallet (vises litt større når det er valgt)
                        Text("\(num)")
                            .font(.system(size: num == value ? 28 : 18, weight: num == value ? .bold : .regular, design: .rounded))
                            .foregroundStyle(num == value ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 60, alignment: .trailing)
                            .scaleEffect(num == value ? 1.1 : 1.0)
                            .animation(.snappy(duration: 0.2), value: value)
                        
                        // Streken (Linjal-merket)
                        Rectangle()
                            .fill(num == value ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: num == value ? 60 : 30, height: 2)
                            .cornerRadius(1)
                    }
                    .frame(height: 50) // Avstand mellom hvert trinn
                    .id(num) // Viktig for scroll-snapping
                    .onTapGesture {
                        withAnimation(.snappy) { value = num }
                    }
                }
                
                // Luft under siste tall
                Spacer().frame(height: 125)
            }
            .scrollTargetLayout()
        }
        // Magien som binder scroll til verdien:
        .scrollPosition(id: Binding(get: { value }, set: { if let v = $0 { value = v } }))
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 250)
        .overlay(
            // En fast markør i midten som viser hvor vi peker
            HStack {
                Spacer()
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.title3)
                    .foregroundStyle(Color.blue)
                    .offset(x: 10) // Juster pilen litt ut til høyre
            }
            .allowsHitTesting(false)
        )
    }
}
