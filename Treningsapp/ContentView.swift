import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // ENDRING: Sorterer nå på sortIndex (lavest tall først = øverst)
    @Query(sort: \CircuitRoutine.sortIndex, order: .forward) private var routines: [CircuitRoutine]
    
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    
    @AppStorage("numberOfRecentCards") private var numberOfRecentCards: Int = 6
    @State private var showingSettings = false
    
    let columns = [GridItem(.adaptive(minimum: 105), spacing: 10)]
    
    var recentRoutines: [CircuitRoutine] {
        Array(routines.prefix(numberOfRecentCards))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // --- 1. HEADER ---
                    HStack {
                        Text("Treningsapp")
                            .font(.largeTitle).bold().foregroundStyle(.primary)
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape").font(.title2).foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(Color(.systemGroupedBackground))
                    
                    // --- 2. ØKT-KORT (STATISK) ---
                    VStack {
                        LazyVGrid(columns: columns, spacing: 10) {
                            
                            // A: KNAPP FOR NY ØKT
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
                            
                            // B: DE SISTE ØKTENE (Sortert etter brukerens valg)
                            ForEach(recentRoutines) { routine in
                                NavigationLink(destination: CircuitDetailView(routine: routine)) {
                                    TreningsKort(routine: routine).aspectRatio(1, contentMode: .fit)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // C: VIS ALLE
                            if routines.count > numberOfRecentCards {
                                NavigationLink(destination: AllRoutinesView()) {
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
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                    
                    // --- 3. HISTORIKK HEADER ---
                    HStack {
                        Text("Historikk").font(.title2).bold()
                        Spacer()
                    }
                    .padding(.horizontal).padding(.bottom, 5)
                    .background(Color(.systemGroupedBackground))
                    
                    // --- 4. HISTORIKK LISTE ---
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
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(maxCount: $numberOfRecentCards).presentationDetents([.fraction(0.3)])
            }
        }
    }

    // ENDRET LOGIKK: Legger ny økt øverst (index 0) og skyver resten ned
    func addRoutine() {
        // 1. Skyv alle eksisterende ned ett hakk
        for routine in routines {
            routine.sortIndex += 1
        }
        
        // 2. Lag ny på index 0
        let newRoutine = CircuitRoutine(name: "Ny Økt")
        newRoutine.sortIndex = 0
        
        modelContext.insert(newRoutine)
        try? modelContext.save()
    }
    
    func deleteLog(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(logs[index]) }
    }
}

// --- INNSTILLINGER ---

struct SettingsSheet: View {
    @Binding var maxCount: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Hjem-skjerm")) {
                    // ENDRET: Range er nå 4 til 7
                    Stepper(value: $maxCount, in: 4...7) {
                        HStack {
                            Text("Antall snarveier")
                            Spacer()
                            Text("\(maxCount)")
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Velg mellom 4 og 7 snarveier (f.eks. en for hver ukedag).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
        }
    }
}

// --- ALL ROUTINES VIEW ---

struct AllRoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Sorterer på sortIndex slik at listen reflekterer brukerens rekkefølge
    @Query(sort: \CircuitRoutine.sortIndex, order: .forward) private var routines: [CircuitRoutine]
    
    // Vi må vite hvor grensen går
    @AppStorage("numberOfRecentCards") private var numberOfRecentCards: Int = 6
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            List {
                // --- SEKSJON 1: DE SOM VISES PÅ FORSIDEN ---
                Section(header: Text("Vises på Hjem-skjermen (\(min(routines.count, numberOfRecentCards)))")) {
                    ForEach(routines.prefix(numberOfRecentCards)) { routine in
                        RoutineRow(routine: routine)
                    }
                    .onMove { indices, newOffset in
                        moveRoutine(from: indices, to: newOffset, section: .top)
                    }
                }
                
                // --- SEKSJON 2: RESTEN AV ØKTENE ---
                if routines.count > numberOfRecentCards {
                    Section(header: Text("Andre økter")) {
                        ForEach(routines.dropFirst(numberOfRecentCards)) { routine in
                            RoutineRow(routine: routine)
                        }
                        .onMove { indices, newOffset in
                            moveRoutine(from: indices, to: newOffset, section: .bottom)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Alle økter")
            .navigationBarTitleDisplayMode(.inline)
            // Edit-knapp for å aktivere flytting
            .toolbar {
                EditButton()
            }
        }
    }
    
    // --- FLYTTE-LOGIKK ---
    
    enum SectionType { case top, bottom }
    
    func moveRoutine(from source: IndexSet, to destination: Int, section: SectionType) {
        // Vi lager en kopi av arrayet som vi kan manipulere
        var updatedRoutines = routines
        
        // Beregn de absolutte indeksene i hele arrayet
        let offset = (section == .bottom) ? numberOfRecentCards : 0
        let adjustedSource = source.map { $0 + offset }
        let adjustedDestination = destination + offset
        
        // Utfør flyttingen på listen
        updatedRoutines.move(fromOffsets: IndexSet(adjustedSource), toOffset: adjustedDestination)
        
        // Oppdater sortIndex på ALLE elementene basert på ny rekkefølge
        for (index, routine) in updatedRoutines.enumerated() {
            routine.sortIndex = index
        }
        
        // Lagre til databasen
        try? modelContext.save()
    }
}

// En enkel rad for listen
struct RoutineRow: View {
    let routine: CircuitRoutine
    
    var body: some View {
        NavigationLink(destination: CircuitDetailView(routine: routine)) {
            HStack {
                VStack(alignment: .leading) {
                    Text(routine.name)
                        .font(.headline)
                    Text("\(routine.segments.count) øvelser")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Gripehåndtak-ikon vises automatisk når man trykker på "Edit"
            }
            .padding(.vertical, 4)
        }
    }
}

// --- HISTORY ROW ---

struct HistoryRow: View {
    let log: WorkoutLog
    
    var body: some View {
        NavigationLink(destination: LogDetailView(log: log)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.routineName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if log.editCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "pencil.circle.fill")
                                Text("\(log.editCount)")
                                    .font(.caption2).bold()
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    
                    Text(log.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Text("\(log.exercises.count) øvelser")
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .primary.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
