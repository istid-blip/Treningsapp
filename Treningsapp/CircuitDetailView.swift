import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// 1. Definisjon av tilstander for skuffen
enum DrawerState: Identifiable {
    case editSegment(CircuitExercise)
    
    var id: String {
        switch self {
        case .editSegment(let segment): return "edit-\(segment.id)"
        }
    }
}

// 2. Definisjon av tilstand for rullehjulet
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
    @Environment(\.dismiss) var dismiss // For å kunne lage vår egen tilbake-knapp
    
    // UI States
    @State private var draggingSegment: CircuitExercise?
    @State private var activeDrawer: DrawerState? = nil // Topp-panelet
    @State private var activePicker: PickerState? = nil // Bunn-panelet
    
    @State private var uiSegments: [CircuitExercise] = []
    
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    let currentTheme: AppTheme = .standard
    
    // Konstanter for høyder
    let pickerHeight: CGFloat = 320
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                
                // --- BAKGRUNN ---
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        
                        // 1. EGEN HEADER (Erstatter standard Navigation Bar)
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.left")
                                        .bold()
                                    Text("Tilbake")
                                }
                                .foregroundStyle(.blue)
                            }
                            
                            Spacer()
                            
                            // Tittel (Flyttet hit)
                            TextField("Navn på økt", text: $routine.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .submitLabel(.done)
                            
                            Spacer()
                            
                            // "Usynlig" knapp for balanse i layout
                            Color.clear.frame(width: 60, height: 44)
                        }
                        .padding(.horizontal)
                        .frame(height: 50) // Standard høyde for header
                        .background(Color(.systemBackground)) // Bakgrunnsfarge
                        .zIndex(1) // Ligger over innholdet som scroller
                        
                        // 2. HOVEDINNHOLD (ScrollView)
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
                                            // 1. Regn ut neste nummer i rekken
                                            let nextNumber = routine.segments.count + 1
                                            let autoName = "Segment \(nextNumber)"
                                            
                                            // 2. Opprett nytt segment med automatisk navn
                                            let newSegment = CircuitExercise(
                                                name: autoName,
                                                durationSeconds: 45,
                                                targetReps: 10,
                                                category: .strength,
                                                note: "",
                                                type: .duration,
                                                sortIndex: routine.segments.count
                                            )
                                            
                                            // 3. Lagre til database og listen
                                            modelContext.insert(newSegment)
                                            routine.segments.append(newSegment)
                                            
                                            // 4. Åpne redigeringsskuffen direkte
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
                    
                    if !routine.segments.isEmpty {
                        NavigationLink(destination: RunCircuitView(routine: routine)) {
                            Text("START TRENING")
                                .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(12).padding().shadow(radius: 5)
                        }
                    }
                }
                .disabled(activeDrawer != nil || activePicker != nil)
                
                // --- DIMMING ---
                if activeDrawer != nil || activePicker != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea() // Dekker ALT, inkludert header
                        .onTapGesture { closeAllPanels() }
                        .transition(.opacity)
                        .zIndex(10)
                }
                
                // --- HOVEDSKUFF (TOPP) ---
                if let drawerState = activeDrawer {
                    // Beregner høyde:
                    // Hvis picker (hjul) er oppe: Skjermhøyde - hjulhøyde.
                    // Hvis ikke: Hele skjermen (+60 for å dekke helt opp forbi dynamic island/status bar).
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
                    .zIndex(11) // Ligger over dimming (10) og header (1)
                    .ignoresSafeArea(.all, edges: .top) // Lar den gå helt til toppen
                }
                
                // --- PICKER SKUFF (BUNN) ---
                if let pickerState = activePicker {
                    DrawerView(theme: currentTheme, edge: .bottom, maxHeight: pickerHeight) {
                        VStack(spacing: 15) {
                            Text(pickerState.title)
                                .font(.headline)
                                .padding(.top, 10)
                            
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
                                    .font(.headline).frame(maxWidth: .infinity).padding().background(Color.blue).foregroundStyle(.white).cornerRadius(12)
                            }
                        }
                    }
                    .zIndex(12)
                }
            }
        } // End GeometryReader
        .toolbar(.hidden, for: .navigationBar) // SKJULER DEN ORIGINALE HEADEREN
        .onAppear { refreshUILoad() }
    }
    
    // --- FUNKSJONER ---
    
    private func closeAllPanels() {
        withAnimation(.snappy) {
            activePicker = nil
            activeDrawer = nil
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshUILoad() }
    }
    
    private func openPickerFor(segment: CircuitExercise) {
        if segment.type == .duration || segment.type == .pause {
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
                TreningsKort(tittel: segment.name, undertittel: segmentDescription(for: segment), ikon: iconForSegment(segment), bakgrunnsfarge: theme.color(for: segment.category), tekstFarge: segment.type == .pause ? .primary : theme.textColor)
                    .onTapGesture { onEdit() }
                    .aspectRatio(1.0, contentMode: .fit)
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                    .onDrag { self.draggingSegment = segment; return NSItemProvider(object: String(describing: segment.persistentModelID) as NSString) }
                
                Button(action: onEditValue) {
                    ZStack { Circle().fill(Color.white).shadow(radius: 2); Text("\(valueToDisplay())").font(.system(size: 12, weight: .bold)).foregroundStyle(.black) }
                        .frame(width: 28, height: 28)
                }
                .offset(x: 8, y: -8)
            }
            .zIndex(1)
            Image(systemName: theme.arrowIcon).font(.title3).fontWeight(.bold).foregroundStyle(theme.arrowColor).frame(width: 20).opacity(isLast ? 0 : 1)
        }
    }
    
    func valueToDisplay() -> Int {
        if segment.type == .duration || segment.type == .pause { return segment.durationSeconds } else { return segment.targetReps }
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
    switch segment.type { case .duration: return "\(segment.durationSeconds) sek"; case .reps: return "\(segment.targetReps) reps"; case .stopwatch: return "Tid på \(segment.targetReps) reps"; case .pause: return "\(segment.durationSeconds) sek hvile" }
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    switch segment.category { case .strength: return "dumbbell.fill"; case .cardio: return "figure.run"; case .combined: return "figure.strengthtraining.functional"; case .other: return "ellipsis.circle.fill" }
}
