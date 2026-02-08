//
//  AllRoutineView.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 08/02/2026.
//

import SwiftUI
import SwiftData

struct AllRoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Vi henter ALLE økter i én sortert liste
    @Query(sort: \CircuitRoutine.sortIndex, order: .forward) private var routines: [CircuitRoutine]
    
    // Vi må vite hvor grensen går (f.eks. 4, 5 eller 6)
    @AppStorage("numberOfRecentCards") private var numberOfRecentCards: Int = 6
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Info-header
                HStack {
                    Image(systemName: "info.circle")
                    Text("Dra øktene opp eller ned for å endre rekkefølge. De \(numberOfRecentCards) øverste vises på forsiden.")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.systemGroupedBackground))
                
                List {
                    // VIKTIG: Alt må ligge i én ForEach for at man skal kunne dra mellom "kategoriene"
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        NavigationLink(destination: CircuitDetailView(routine: routine)) {
                            HStack {
                                // 1. VISUELL INDIKATOR (Grønn hvis på forsiden, Grå hvis ikke)
                                if index < numberOfRecentCards {
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
                                        .foregroundStyle(index < numberOfRecentCards ? .primary : .secondary)
                                    
                                    Text("\(routine.segments.count) øvelser")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // 3. EKSTRA TEKST SOM FORKLARER STATUS
                                if index < numberOfRecentCards {
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
                        }
                        // Litt annen bakgrunn på de som er "aktive" for å skille dem ut
                        .listRowBackground(
                            index < numberOfRecentCards ? Color.white : Color(.systemGray6).opacity(0.5)
                        )
                    }
                    .onMove(perform: moveRoutine)
                    .onDelete(perform: deleteRoutine)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Alle økter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
            }
        }
    }
    
    // --- LOGIKK FOR FLYTTING ---
    
    func moveRoutine(from source: IndexSet, to destination: Int) {
        // 1. Utfør flyttingen i arrayet (i minnet)
        var updatedRoutines = routines
        updatedRoutines.move(fromOffsets: source, toOffset: destination)
        
        // 2. Oppdater sortIndex for ALLE elementene basert på ny rekkefølge
        // Dette gjør at "grensen" for forsiden automatisk gjelder de nye som havner på topp
        for (index, routine) in updatedRoutines.enumerated() {
            routine.sortIndex = index
        }
        
        // 3. Lagre endringen permanent
        try? modelContext.save()
    }
    
    func deleteRoutine(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}
