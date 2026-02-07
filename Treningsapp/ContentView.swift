import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // Sorterer nyeste økter først
    @Query(sort: \CircuitRoutine.createdDate, order: .reverse) private var routines: [CircuitRoutine]
    
    @State private var navigationPath = [CircuitRoutine]()
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    
                    // --- NY ØKT KNAPP (Forenklet) ---
                    Button(action: createNewRoutine) {
                        TreningsKort(
                            tittel: "Ny økt",
                            ikon: "plus",
                            bakgrunnsfarge: Color(.systemGray5),
                            tekstFarge: .blue
                        )
                    }

                    // --- EKSISTERENDE ØKTER ---
                    ForEach(routines) { routine in
                        NavigationLink(value: routine) {
                            TreningsKort(
                                tittel: routine.name,
                                undertittel: "\(routine.segments.count) deler",
                                bakgrunnsfarge: .blue
                            )
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(routine)
                            } label: {
                                Label("Slett økt", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Mine Sirkeløkter")
            .navigationDestination(for: CircuitRoutine.self) { routine in
                CircuitDetailView(routine: routine)
                    // Rydder opp hvis økten er tom når vi går tilbake
                    .onDisappear {
                        cleanUpRoutine(routine)
                    }
            }
        }
    }

    // --- FUNKSJONER ---

    private func createNewRoutine() {
        // 1. Opprett en generell ny økt
        let newRoutine = CircuitRoutine(name: "Ny økt")
        
        // 2. Sett inn i databasen med en gang (viktig for navigering)
        modelContext.insert(newRoutine)
        
        // 3. Naviger til detaljvisning
        navigationPath.append(newRoutine)
    }
    
    // Sletter økten automatisk hvis den er tom (ingen segmenter)
    private func cleanUpRoutine(_ routine: CircuitRoutine) {
        if routine.segments.isEmpty && !routine.isDeleted {
            print("Sletter tom økt: \(routine.name)")
            modelContext.delete(routine)
        }
    }
}
