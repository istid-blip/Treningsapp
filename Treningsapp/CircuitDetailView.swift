import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CircuitDetailView: View {
    @Bindable var routine: CircuitRoutine
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSegment = false
    @State private var draggingSegment: CircuitExercise?
    
    let columns = [GridItem(.adaptive(minimum: 150), spacing: 24)]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    TextField("Navn på økt", text: $routine.name)
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                        .submitLabel(.done)
                        .onChange(of: routine.name) { ensureSaved() }
                    
                    LazyVGrid(columns: columns, spacing: 24) {
                        
                        // 1. SEGMENTENE
                        ForEach(Array(routine.segments.enumerated()), id: \.element.id) { index, segment in
                            DraggableSegmentView(
                                routine: routine,
                                segment: segment,
                                index: index,
                                totalCount: routine.segments.count,
                                draggingSegment: $draggingSegment,
                                onDelete: { deleteSegment(segment) }
                            )
                        }
                        
                        // 2. LEGG TIL KNAPP
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
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
            }
            .animation(.default, value: routine.segments)
            
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
            AddSegmentView(routine: routine)
        }
    }
    
    private func ensureSaved() {
        if routine.modelContext == nil { modelContext.insert(routine) }
    }
    
    private func deleteSegment(_ segment: CircuitExercise) {
        if let index = routine.segments.firstIndex(of: segment) {
            routine.segments.remove(at: index)
            modelContext.delete(segment)
        }
    }
}

// --- DRAGGABLE VIEW ---
struct DraggableSegmentView: View {
    var routine: CircuitRoutine
    var segment: CircuitExercise
    var index: Int
    var totalCount: Int
    @Binding var draggingSegment: CircuitExercise?
    var onDelete: () -> Void
    
    var body: some View {
        NavigationLink(value: routine) {
            TreningsKort(
                tittel: segment.name,
                undertittel: segmentDescription(for: segment),
                ikon: iconForSegment(segment),
                bakgrunnsfarge: colorForSegment(segment),
                tekstFarge: segment.type == .pause ? .primary : .white,
                visPil: index < totalCount - 1
            )
        }
        .buttonStyle(.plain)
        .onDrag {
            self.draggingSegment = segment
            return NSItemProvider(object: String(describing: segment.persistentModelID) as NSString)
        }
        .onDrop(of: [.text], delegate: SegmentDropDelegate(
            item: segment,
            items: Binding(get: { routine.segments }, set: { routine.segments = $0 }),
            draggingItem: $draggingSegment
        ))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Slett", systemImage: "trash")
            }
        }
    }
}

// --- DRAG & DROP DELEGATE ---
struct SegmentDropDelegate: DropDelegate {
    let item: CircuitExercise
    @Binding var items: [CircuitExercise]
    @Binding var draggingItem: CircuitExercise?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        if draggingItem.id != item.id {
            guard let fromIndex = items.firstIndex(of: draggingItem),
                  let toIndex = items.firstIndex(of: item) else { return }
            
            withAnimation {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}

// --- HJELPEFUNKSJONER ---
func segmentDescription(for segment: CircuitExercise) -> String {
    switch segment.type {
    case .duration: return "\(segment.durationSeconds) sek"
    case .reps: return "\(segment.targetReps) reps"
    case .stopwatch: return "Tid på \(segment.targetReps) reps"
    case .pause: return "\(segment.durationSeconds) sek hvile"
    }
}

// --- ENDRING: Bruker nå switch på Enum ---
func colorForSegment(_ segment: CircuitExercise) -> Color {
    if segment.type == .pause { return Color(.systemGray5) }
    
    switch segment.category {
    case .strength: return .blue
    case .cardio: return .red
    case .mobility: return .green
    case .core: return .orange
    case .pause: return .gray // Fallback, fanges gjerne av if-sjekken over
    }
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    if segment.type == .pause { return "cup.and.saucer.fill" }
    
    switch segment.category {
    case .strength: return "dumbbell.fill"
    case .cardio: return "figure.run"
    case .mobility: return "figure.flexibility"
    case .core: return "figure.core.training"
    default: return nil
    }
}
