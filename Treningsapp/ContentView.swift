import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CircuitRoutine.createdDate, order: .reverse) private var routines: [CircuitRoutine]
    
    @State private var navigationPath = [CircuitRoutine]()
    @State private var isSelectingType = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    
                    // --- MENY FOR NY ØKT ---
                    Group {
                        if isSelectingType {
                            VStack(spacing: 4) {
                                listeKnapp(tittel: "Styrke", farge: .blue)
                                listeKnapp(tittel: "Kondisjon", farge: .red)
                                listeKnapp(tittel: "Core", farge: .orange)
                                
                                Button(action: {
                                    withAnimation { isSelectingType = false }
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.2))
                                        Image(systemName: "xmark")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .aspectRatio(1.0, contentMode: .fit)
                            
                        } else {
                            Button(action: {
                                withAnimation { isSelectingType = true }
                            }) {
                                TreningsKort(
                                    tittel: "Ny økt",
                                    ikon: "plus",
                                    bakgrunnsfarge: Color(.systemGray5),
                                    tekstFarge: .blue
                                )
                            }
                        }
                    }

                    // --- EKSISTERENDE ØKTER ---
                    ForEach(routines) { routine in
                        NavigationLink(value: routine) {
                            TreningsKort(
                                tittel: routine.name,
                                // ENDRET HER: exercises -> segments
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
            }
        }
    }

    private func listeKnapp(tittel: String, farge: Color) -> some View {
        Button(action: {
            createRoutine(type: tittel)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(farge)
                Text(tittel)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func createRoutine(type: String) {
        withAnimation { isSelectingType = false }
        
        let newRoutine = CircuitRoutine(name: "Ny \(type)økt")
        // Vi lagrer ikke til database her (Lazy Save), bare legger til i path
        navigationPath.append(newRoutine)
    }
}
