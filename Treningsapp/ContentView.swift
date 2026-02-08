import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CircuitRoutine.sortIndex, order: .forward) private var routines: [CircuitRoutine]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    
    @AppStorage("numberOfRecentCards") private var numberOfRecentCards: Int = 6
    @State private var showingSettings = false
    
    // Styrer navigering til økt
    @State private var routineToNavigate: CircuitRoutine?
    
    // NYTT: Styrer skuffen for alle økter
    @State private var showingAllRoutinesDrawer = false
    
    let columns = [GridItem(.adaptive(minimum: 105), spacing: 10)]
    
    var recentRoutines: [CircuitRoutine] {
        Array(routines.prefix(numberOfRecentCards))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) { // ZStack lar oss legge skuffen oppå
                
                // --- HOVEDINNHOLD ---
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // HEADER
                    HStack {
                        Text("Treningsapp").font(.largeTitle).bold().foregroundStyle(.primary)
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape").font(.title2).foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 10)
                    .background(Color(.systemGroupedBackground))
                    
                    // ØKT-KORT
                    VStack {
                        LazyVGrid(columns: columns, spacing: 10) {
                            // A: NY ØKT
                            Button(action: addRoutine) {
                                VStack {
                                    Image(systemName: "plus").font(.title).foregroundStyle(.white)
                                    Text("Ny").font(.caption).bold().foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(Color.blue)
                                .cornerRadius(12)
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            
                            // B: SISTE ØKTER
                            ForEach(recentRoutines) { routine in
                                Button(action: { routineToNavigate = routine }) {
                                    TreningsKort(routine: routine).aspectRatio(1, contentMode: .fit)
                                }
                            }
                            
                            // C: VIS ALLE (Åpner nå skuffen)
                            if routines.count > numberOfRecentCards {
                                Button(action: { withAnimation(.snappy) { showingAllRoutinesDrawer = true } }) {
                                    VStack {
                                        Image(systemName: "list.bullet").font(.title).foregroundStyle(.primary)
                                        Text("Vis alle").font(.caption).bold().foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal).padding(.bottom, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                    
                    // HISTORIKK
                    HStack {
                        Text("Historikk").font(.title2).bold()
                        Spacer()
                    }
                    .padding(.horizontal).padding(.bottom, 5)
                    .background(Color(.systemGroupedBackground))
                    
                    List {
                        ForEach(logs) { log in
                            HistoryRow(log: log)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteLog)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal)
                }
                .disabled(showingAllRoutinesDrawer) // Deaktiver bakgrunn når skuffen er oppe
                
                // --- DIMMING BAKGRUNN ---
                if showingAllRoutinesDrawer {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.snappy) { showingAllRoutinesDrawer = false }
                        }
                        .transition(.opacity)
                        .zIndex(10)
                }
                
                // --- SKUFF FOR ALLE ØKTER ---
                if showingAllRoutinesDrawer {
                    DrawerView(theme: .standard, edge: .top, maxHeight: 600) {
                        VStack(spacing: 0) {
                            
                            Text("Alle økter")
                                .font(.headline)
                                .padding(.top, 20)
                                .padding(.bottom, 10)
                            
                            // Listen med økter (med select-funksjon)
                            AllRoutinesView(onSelect: { selectedRoutine in
                                // Når en økt velges: Lukk skuffen og naviger
                                withAnimation(.snappy) {
                                    showingAllRoutinesDrawer = false
                                }
                                // Vent bittelitt så animasjonen ser pen ut før bytte
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    routineToNavigate = selectedRoutine
                                }
                            })
                        }
                    }
                    .zIndex(11)
                    .transition(.move(edge: .bottom))
                }
            }
            // Navigering skjer her
            .navigationDestination(item: $routineToNavigate) { routine in
                CircuitDetailView(routine: routine)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(maxCount: $numberOfRecentCards).presentationDetents([.fraction(0.3)])
            }
        }
    }

    func addRoutine() {
        let baseName = "Ny Økt"
        var newName = baseName
        var counter = 2
        let existingNames = routines.map { $0.name }
        while existingNames.contains(newName) {
            newName = "\(baseName) \(counter)"
            counter += 1
        }
        
        for routine in routines { routine.sortIndex += 1 }
        
        let newRoutine = CircuitRoutine(name: newName)
        newRoutine.sortIndex = 0
        modelContext.insert(newRoutine)
        
        routineToNavigate = newRoutine
        try? modelContext.save()
    }
    
    func deleteLog(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(logs[index]) }
    }
}

struct SettingsSheet: View {
    @Binding var maxCount: Int
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Hjem-skjerm")) {
                    Stepper(value: $maxCount, in: 1...7) {
                        HStack { Text("Antall snarveier"); Spacer(); Text("\(maxCount)").bold().foregroundStyle(.secondary) }
                    }
                    Text("Velg mellom 4 og 7 snarveier.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Ferdig") { dismiss() } } }
        }
    }
}

struct HistoryRow: View {
    let log: WorkoutLog
    var body: some View {
        NavigationLink(destination: LogDetailView(log: log)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.routineName).font(.headline).foregroundStyle(.primary)
                        if log.editCount > 0 {
                            HStack(spacing: 2) { Image(systemName: "pencil.circle.fill"); Text("\(log.editCount)").font(.caption2).bold() }.foregroundStyle(.orange)
                        }
                    }
                    Text(log.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack { Text("\(log.exercises.count) øvelser"); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray) }
                .font(.subheadline).padding(.horizontal, 10).padding(.vertical, 5)
            }
            .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: .primary.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
