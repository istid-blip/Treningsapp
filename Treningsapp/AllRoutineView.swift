import SwiftUI
import SwiftData

struct AllRoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Sortert liste over alle økter
    @Query(sort: \CircuitRoutine.sortIndex, order: .forward) private var routines: [CircuitRoutine]
    
    @AppStorage("numberOfRecentCards") private var numberOfRecentCards: Int = 6
    
    // NYTT: En 'closure' som kalles når brukeren velger en økt fra skuffen
    var onSelect: ((CircuitRoutine) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Info-header
            HStack {
                Image(systemName: "info.circle")
                Text("Dra øktene opp eller ned for å endre rekkefølge. De \(numberOfRecentCards) øverste vises på forsiden.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)
            .padding()
            .background(Color(.systemGroupedBackground))
            
            List {
                ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                    // VIKTIG: Vi bruker en hjelpe-view for å velge mellom NavigationLink eller Button
                    RowContent(
                        routine: routine,
                        index: index,
                        limit: numberOfRecentCards,
                        action: {
                            // Hvis onSelect finnes (vi er i skuffen), kjør den.
                            if let onSelect = onSelect {
                                onSelect(routine)
                            }
                        }
                    )
                    // Hvis vi IKKE er i skuffen (onSelect er nil), bruk NavigationLink-oppførsel
                    .background(
                        Group {
                            if onSelect == nil {
                                NavigationLink("", destination: CircuitDetailView(routine: routine))
                                    .opacity(0)
                            }
                        }
                    )
                    .listRowBackground(
                        index < numberOfRecentCards ? Color(.secondarySystemGroupedBackground) : Color(.systemGray6).opacity(0.5)
                    )
                }
                .onMove(perform: moveRoutine)
                .onDelete(perform: deleteRoutine)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden) // Lar skuffens bakgrunn synes
        }
        .background(Color(.systemGroupedBackground))
        // Fjernet NavigationTitle herfra for å passe bedre i skuffen
    }
    
    // --- HJELPEVIEW FOR RADEN ---
    struct RowContent: View {
        let routine: CircuitRoutine
        let index: Int
        let limit: Int
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    // 1. VISUELL INDIKATOR
                    if index < limit {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("\(index + 1)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.green))
                    } else {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.gray))
                    }
                    
                    // 2. NAVN OG INFO
                    VStack(alignment: .leading) {
                        Text(routine.name)
                            .font(.headline)
                            .foregroundStyle(index < limit ? .primary : .secondary)
                        
                        Text("\(routine.segments.count) øvelser")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // 3. STATUS
                    if index < limit {
                        Text("På forsiden")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle()) // Gjør hele raden trykkbar
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // --- LOGIKK FOR FLYTTING ---
    func moveRoutine(from source: IndexSet, to destination: Int) {
        var updatedRoutines = routines
        updatedRoutines.move(fromOffsets: source, toOffset: destination)
        for (index, routine) in updatedRoutines.enumerated() {
            routine.sortIndex = index
        }
        try? modelContext.save()
    }
    
    func deleteRoutine(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}
