import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CircuitDetailView: View {
    @Bindable var routine: CircuitRoutine
    @Environment(\.modelContext) private var modelContext
    
    // UI States
    @State private var showAddSegment = false
    @State private var draggingSegment: CircuitExercise?
    @State private var selectedSegmentForEdit: CircuitExercise?
    
    // Lokal liste som fungerer som en "buffer" for stabil visning
    @State private var uiSegments: [CircuitExercise] = []

    let columns = [GridItem(.adaptive(minimum: 150), spacing: 24)]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Navn på økt - SwiftData lagrer dette automatisk via @Bindable
                    TextField("Navn på økt", text: $routine.name)
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                        .submitLabel(.done)
                    
                    LazyVGrid(columns: columns, spacing: 24) {
                        
                        // Bruker standard Identifiable ID (segment)
                        ForEach(uiSegments) { segment in
                            DraggableSegmentView(
                                segment: segment,
                                draggingSegment: $draggingSegment,
                                onEdit: { selectedSegmentForEdit = segment }
                            )
                            .onDrag {
                                self.draggingSegment = segment
                                return NSItemProvider(object: String(describing: segment.persistentModelID) as NSString)
                            }
                            .onDrop(of: [.text], delegate: GridDropDelegate(
                                item: segment,
                                items: $uiSegments,
                                draggingItem: $draggingSegment,
                                onSave: saveSortOrder
                            ))
                        }
                        
                        // LEGG TIL KNAPP
                        Button(action: { showAddSegment = true }) {
                            TreningsKort(
                                tittel: "Legg til",
                                ikon: "plus",
                                bakgrunnsfarge: Color(.systemGray6),
                                tekstFarge: .blue,
                                visPil: false
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundStyle(Color.blue.opacity(0.5))
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120)
                }
            }
            .animation(.snappy, value: uiSegments)
            
            // START KNAPP
            if !routine.segments.isEmpty {
                NavigationLink(destination: RunCircuitView(routine: routine)) {
                    Text("START TRENING")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding()
                        .shadow(radius: 5)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSegment) {
            AddSegmentView(routine: routine, segmentToEdit: nil)
                .onDisappear { refreshUILoad() }
        }
        .sheet(item: $selectedSegmentForEdit) { segment in
            AddSegmentView(routine: routine, segmentToEdit: segment)
                .onDisappear { refreshUILoad() }
        }
        .onAppear {
            refreshUILoad()
        }
    }
    
    // --- FUNKSJONER ---

    private func refreshUILoad() {
        // Vasker listen for eventuelle duplikater før sortering og visning
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

// --- DRAGGABLE VIEW COMPONENT ---

struct DraggableSegmentView: View {
    var segment: CircuitExercise
    @Binding var draggingSegment: CircuitExercise?
    var onEdit: () -> Void
    
    var body: some View {
        TreningsKort(
            tittel: segment.name,
            undertittel: segmentDescription(for: segment),
            ikon: iconForSegment(segment),
            bakgrunnsfarge: colorForSegment(segment),
            tekstFarge: segment.type == .pause ? .primary : .white,
            visPil: false
        )
        .onTapGesture {
            onEdit()
        }
    }
}

// --- GRID DROP DELEGATE ---

struct GridDropDelegate: DropDelegate {
    let item: CircuitExercise
    @Binding var items: [CircuitExercise]
    @Binding var draggingItem: CircuitExercise?
    var onSave: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        onSave()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        if draggingItem.id != item.id {
            guard let fromIndex = items.firstIndex(of: draggingItem),
                  let toIndex = items.firstIndex(of: item) else { return }
            
            withAnimation(.snappy) {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}

// --- STYLES & HELPERS ---

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

func segmentDescription(for segment: CircuitExercise) -> String {
    switch segment.type {
    case .duration: return "\(segment.durationSeconds) sek"
    case .reps: return "\(segment.targetReps) reps"
    case .stopwatch: return "Tid på \(segment.targetReps) reps"
    case .pause: return "\(segment.durationSeconds) sek hvile"
    }
}

func colorForSegment(_ segment: CircuitExercise) -> Color {
    switch segment.category {
    case .strength: return .blue
    case .cardio: return .red
    case .combined: return .purple
    case .other: return .gray
    }
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    switch segment.category {
    case .strength: return "dumbbell.fill"
    case .cardio: return "figure.run"
    case .combined: return "figure.strengthtraining.functional"
    case .other: return "ellipsis.circle.fill"
    }
}
