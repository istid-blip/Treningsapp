import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Henter maler (Routines)
    @Query(sort: \CircuitRoutine.createdDate, order: .reverse) private var routines: [CircuitRoutine]
    
    // Henter historikk (Logs) - Nyeste øverst
    @Query(sort: \WorkoutLog.date, order: .reverse) private var history: [WorkoutLog]
    
    @State private var navigationPath = [CircuitRoutine]()
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // --- SEKSJON 1: MINE ØKTER ---
                    VStack(alignment: .leading) {
                        Text("Mine Økter")
                            .font(.title2).bold()
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            // Ny økt knapp
                            Button(action: createNewRoutine) {
                                TreningsKort(
                                    tittel: "Ny økt",
                                    ikon: "plus",
                                    bakgrunnsfarge: Color(.systemGray5),
                                    tekstFarge: .blue
                                )
                            }

                            // Eksisterende økter
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
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // --- SEKSJON 2: HISTORIKK ---
                    VStack(alignment: .leading) {
                        Text("Historikk")
                            .font(.title2).bold()
                            .padding(.horizontal)
                        
                        if history.isEmpty {
                            Text("Ingen loggførte økter enda.")
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(history) { log in
                                    HistoryRow(log: log)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                modelContext.delete(log)
                                            } label: {
                                                Label("Slett logg", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Treningsapp")
            
            // --- SETTINGS KNAPP ---
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { print("Settings tapped") }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.gray)
                    }
                }
            }
            
            .navigationDestination(for: CircuitRoutine.self) { routine in
                CircuitDetailView(routine: routine)
                    .onDisappear { cleanUpRoutine(routine) }
            }
        }
    }

    // --- FUNKSJONER ---

    private func createNewRoutine() {
        let newRoutine = CircuitRoutine(name: "Ny økt")
        modelContext.insert(newRoutine)
        navigationPath.append(newRoutine)
    }
    
    private func cleanUpRoutine(_ routine: CircuitRoutine) {
        if routine.segments.isEmpty && !routine.isDeleted {
            modelContext.delete(routine)
        }
    }
}

// --- KOMPONENT FOR HISTORIKK-RAD ---
// --- KOMPONENT FOR HISTORIKK-RAD ---
struct HistoryRow: View {
    let log: WorkoutLog
    
    var body: some View {
        NavigationLink(destination: LogDetailView(log: log)) { // <-- Link til den nye visningen
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.routineName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        // VIS "REDIGERT" MERKE
                        if log.wasEdited {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Text(log.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Viser antall øvelser
                HStack {
                    Text("\(log.exercises.count) øvelser")
                    Image(systemName: "chevron.right") // Indikerer at den kan åpnes
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle()) // Fjerner blå link-farge
    }
}
