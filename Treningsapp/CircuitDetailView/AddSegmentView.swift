//
//  AddSegmentView.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 06/02/2026.
//

import SwiftUI
import SwiftData

struct AddSegmentView: View {
    @Environment(\.modelContext) var modelContext
    
    // --- Modus 1: Redigere rutine ---
    var routine: CircuitRoutine?
    var segmentToEdit: CircuitExercise?
    
    // --- Modus 2: Redigere logg (Historikk) ---
    var log: WorkoutLog?
    var logEntryToEdit: LoggedExercise?
    
    // Hvilket felt er aktivt?
    var currentActiveField: String? = nil
    
    var onDismiss: () -> Void
    var onRequestPicker: (String, Binding<Int>, ClosedRange<Int>, Int) -> Void
    var onTyping: () -> Void
    
    // Callbacks
    var onSwitchSegment: ((CircuitExercise) -> Void)?
    var onSwitchLogEntry: ((LoggedExercise) -> Void)?
    
    // Henter alle rutiner for å finne tidligere brukte øvelsesnavn
        @Query var allRoutines: [CircuitRoutine]

        // En hardkodet liste med "fabrikk-øvelser" og deres standardkategori
    private let standardExercises: [(name: String, category: ExerciseCategory)] = [
            ("Knebøy", .strength), ("Benkpress", .strength), ("Markløft", .strength),
            ("Pushups", .strength), ("Pullups", .strength), ("Utfall", .strength),
            ("Skulderpress", .strength), ("Militærpress", .strength),
            ("Løping", .cardio), ("Intervaller", .cardio), ("Sykling", .cardio),
            ("Roing", .cardio),
            ("Planken", .combined), ("Situps", .combined), ("Rygghev", .combined),
            ("Yoga", .combined), ("Uttøying", .combined), ("Balansebrett", .combined),
            ("Pause", .other)
        ]
    
    
    @State private var name = ""
    @State private var selectedCategory: ExerciseCategory = .strength
    @State private var note = ""
    
    @State private var duration = 0
    @State private var targetReps = 10
    @State private var weight: Double = 0.0
    @State private var distance: Double = 0.0
    
    @State private var showDeleteConfirmation = false
    
    @FocusState private var isNameFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    enum ActiveField { case name, note, reps, weight, time, distance }
    @State private var activeField: ActiveField? = nil
    
    // --- Navigasjon Rutine ---
    private var sortedSegments: [CircuitExercise] {
        routine?.segments.sorted { $0.sortIndex < $1.sortIndex } ?? []
    }
    private var previousSegment: CircuitExercise? {
        guard let current = segmentToEdit, let index = sortedSegments.firstIndex(of: current) else { return nil }
        return index > 0 ? sortedSegments[index - 1] : nil
    }
    private var nextSegment: CircuitExercise? {
        guard let current = segmentToEdit, let index = sortedSegments.firstIndex(of: current) else { return nil }
        return index < sortedSegments.count - 1 ? sortedSegments[index + 1] : nil
    }
    
    // --- Navigasjon Logg ---
    private var sortedLogEntries: [LoggedExercise] {
            // Endret: Sorter på sortIndex slik at pilene følger listen i LogDetailView
            log?.exercises.sorted { $0.sortIndex < $1.sortIndex } ?? []
        }
    private var previousLogEntry: LoggedExercise? {
        guard let current = logEntryToEdit, let index = sortedLogEntries.firstIndex(of: current) else { return nil }
        return index > 0 ? sortedLogEntries[index - 1] : nil
    }
    private var nextLogEntry: LoggedExercise? {
        guard let current = logEntryToEdit, let index = sortedLogEntries.firstIndex(of: current) else { return nil }
        return index < sortedLogEntries.count - 1 ? sortedLogEntries[index + 1] : nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. NAVN MED PILER
                    nameInputSection
                    
                    // 2. KATEGORI
                    categorySection
                    
                    // 3. SMARTE INNDATAFELT
                    inputGridSection
                    
                    // 4. NOTATER
                    noteSection
                    
                    Spacer(minLength: 20)
                    
                    // SLETT KNAPP
                    deleteButton
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            loadData()
        }
        // Last inn på nytt hvis vi bytter øvelse
        .onChange(of: segmentToEdit) { _, _ in loadData() }
        .onChange(of: logEntryToEdit) { _, _ in loadData() }
        
        // Oppdatering av modell når lokale verdier endres
        .onChange(of: duration) { _, _ in updateSegment() }
        .onChange(of: targetReps) { _, _ in updateSegment() }
        .onChange(of: weight) { _, _ in updateSegment() }
        .onChange(of: distance) { _, _ in updateSegment() }
        
        .onChange(of: segmentToEdit?.durationSeconds) { _, newValue in
            if let val = newValue, val != duration {
                duration = val
            }
        }
        
        .onChange(of: activeField) { _, current in
            if current != .name { isNameFocused = false }
            if current != .note { isNoteFocused = false }
        }
        
        .alert("Slett?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Slett", role: .destructive) { deleteSegment() }
        } message: {
            Text("Er du sikker på at du vil fjerne denne delen?")
        }
    }
    
    // --- VIEW COMPONENTS ---
    
    var nameInputSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Øvelsesnavn")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 4) // Justerer label litt inn
                
                // Container for input + dropdown
                ZStack(alignment: .top) {
                    
                    // --- SELVE INPUT-RADEN (Piler + Felt) ---
                    HStack(spacing: 12) {
                        // VENSTRE PIL
                        Button(action: {
                            if let prev = previousSegment { onSwitchSegment?(prev) }
                            else if let prevLog = previousLogEntry { onSwitchLogEntry?(prevLog) }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .background(Color(.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        .disabled(!canGoBack)
                        
                        // TEKSTFELTET
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            
                            TextField("F.eks. Knebøy", text: $name)
                                .font(.body) // Litt strammere font
                                .submitLabel(.done)
                                .focused($isNameFocused)
                                .onChange(of: name) { _, _ in updateSegment() }
                                .onChange(of: isNameFocused) { _, focused in
                                    if focused {
                                        onTyping()
                                        activeField = .name
                                    }
                                }
                            
                            if !name.isEmpty && isNameFocused {
                                Button(action: { name = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(activeField == .name ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        
                        // HØYRE PIL
                        Button(action: {
                            if let next = nextSegment { onSwitchSegment?(next) }
                            else if let nextLog = nextLogEntry { onSwitchLogEntry?(nextLog) }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .background(Color(.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        .disabled(!canGoForward)
                    }
                    .zIndex(2) // Sørger for at input-raden alltid er øverst
                    
                    // --- DEN NYE LEKRE LISTEN ---
                    if isNameFocused && !exerciseSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            // Usynlig spacer for å dytte listen ned under tekstfeltet
                            // (44pt + litt margin)
                            Color.clear.frame(height: 55)
                            
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(exerciseSuggestions, id: \.0) { suggestion in
                                        Button(action: {
                                            withAnimation(.snappy) {
                                                name = suggestion.0
                                                selectedCategory = suggestion.1
                                                applySmartDefaults()
                                                updateSegment()
                                                isNameFocused = false
                                                activeField = nil
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                // Kategori-ikon
                                                ZStack {
                                                    Circle()
                                                        .fill(categoryColor(for: suggestion.1).opacity(0.15))
                                                        .frame(width: 32, height: 32)
                                                    
                                                    Image(systemName: categoryIcon(for: suggestion.1))
                                                        .font(.caption.bold())
                                                        .foregroundStyle(categoryColor(for: suggestion.1))
                                                }
                                                
                                                // Navn
                                                Text(suggestion.0)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                
                                                Spacer()
                                                
                                                // Kategori-tekst
                                                Text(suggestion.1.rawValue)
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color(.tertiarySystemFill))
                                                    .clipShape(Capsule())
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                            .contentShape(Rectangle())
                                        }
                                        
                                        if suggestion.0 != exerciseSuggestions.last?.0 {
                                            Divider().padding(.leading, 60) // Indented divider
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .frame(maxHeight: 220) // Begrenser høyden
                            .background(.regularMaterial) // Frosted glass effekt!
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 56) // Samme bredde-justering som før for å matche feltet
                        }
                        .zIndex(10) // Ligger over alt annet
                        .transition(.opacity.combined(with: .move(edge: .top)).animation(.snappy))
                    }
                }
            }
            .zIndex(100)
        }
    
    var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kategori")
                .font(.caption).foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(.snappy) {
                            selectedCategory = category
                            applySmartDefaults()
                            updateSegment()
                        }
                    }) {
                        Text(category.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedCategory == category
                                ? AppTheme.standard.color(for: category)
                                : Color(.systemGray6)
                            )
                            .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
    
    var inputGridSection: some View {
        HStack(spacing: 12) {
            if showReps {
                CompactInputCell(
                    value: "\(targetReps)",
                    label: "Reps",
                    isActive: activeField == .reps,
                    action: {
                        activeField = .reps; onRequestPicker("Antall reps", $targetReps, 1...100, 1) }
                )
            }
            
            if showWeight {
                CompactInputCell(
                    value: weight == 0 ? "-" : String(format: "%.0f", weight),
                    label: "kg",
                    isActive: activeField == .weight,
                    action: {
                        activeField = .weight
                        let weightBinding = Binding<Int>(
                            get: { Int(weight) },
                            set: { weight = Double($0) }
                        )
                        onRequestPicker("Vekt (kg)", weightBinding, 0...300, 1)
                    }
                )
            }
            
            if showTime {
                CompactInputCell(
                    value: duration >= 60 ? String(format: "%d:%02d", duration / 60, duration % 60) : "\(duration)",
                    label: "Tid",
                    isActive: activeField == .time,
                    action: {
                        activeField = .time
                        onRequestPicker("Tid", $duration, 0...3600, 5)
                    }
                )
            }
            if showDistance {
                CompactInputCell(
                    value: distance == 0 ? "-" : String(format: "%.0f", distance),
                    label: "Meter",
                    isActive: activeField == .distance,
                    action: { activeField = .distance
                        let distBinding = Binding<Int>(
                            get: { Int(distance) },
                            set: { distance = Double($0) }
                        )
                        onRequestPicker("Meter", distBinding, 0...10000, 50)
                    }
                )
            }
        }
    }
    
    var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notater")
                .font(.caption).foregroundStyle(.secondary)
            
            TextField("Valgfritt...", text: $note)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(activeField == .note ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(activeField == .note ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .cornerRadius(12)
                .focused($isNoteFocused)
                .submitLabel(.done)
                .onChange(of: note) { _, _ in updateSegment() }
                .onChange(of: isNoteFocused) { _, focused in
                    if focused { onTyping()
                        activeField = .note}
                }
        }
    }
    
    var deleteButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack {
                Image(systemName: "trash")
                Text("Slett del")
            }
            .foregroundStyle(Color.red)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // --- LOGIC ---
    
    var canGoBack: Bool { previousSegment != nil || previousLogEntry != nil }
    var canGoForward: Bool { nextSegment != nil || nextLogEntry != nil }
    
    var showReps: Bool { selectedCategory == .strength || selectedCategory == .combined }
    var showWeight: Bool { selectedCategory == .strength || selectedCategory == .combined }
    var showTime: Bool { selectedCategory == .cardio || selectedCategory == .other || selectedCategory == .combined }
    var showDistance: Bool { selectedCategory == .cardio || selectedCategory == .combined }
    
    var exerciseSuggestions: [(String, ExerciseCategory)] {
            // 1. Samle alle navn fra tidligere rutiner
            let historyNames = allRoutines.flatMap { $0.segments }.map { ($0.name, $0.category) }
            
            // 2. Slå sammen med standardlisten
            let allSource = standardExercises + historyNames
            
            // 3. Fjern duplikater (vi bruker navn som nøkkel)
            var unique = [String: ExerciseCategory]()
            for item in allSource {
                // Hvis navnet ikke finnes, eller vi overskriver med en standard, legg til.
                // (Her prioriterer vi bare første treff for enkelhets skyld)
                if unique[item.0] == nil {
                    unique[item.0] = item.1
                }
            }
            
            let allUnique = unique.map { key, value in (key, value) }
            
            // 4. Filtrer basert på tekst input
            if name.isEmpty {
                // Hvis tomt felt: Vis alfabetisk liste (begrens antall for ytelse)
                return allUnique.sorted { $0.0 < $1.0 }.prefix(20).map { $0 }
            } else {
                // Hvis bruker skriver: Vis treff som inneholder teksten
                return allUnique
                    .filter { $0.0.localizedCaseInsensitiveContains(name) }
                    .sorted { $0.0 < $1.0 }
            }
        }
    
    func loadData() {
        if let segment = segmentToEdit {
            name = segment.name
            selectedCategory = segment.category
            note = segment.note
            duration = segment.durationSeconds
            targetReps = segment.targetReps
            weight = segment.weight
            distance = segment.distance
            
            updateActiveFieldFromParent()
            
        } else if let logEntry = logEntryToEdit {
            name = logEntry.name
            selectedCategory = logEntry.category
            note = logEntry.note
            duration = logEntry.durationSeconds
            targetReps = logEntry.targetReps
            weight = logEntry.weight
            distance = logEntry.distance
            
            updateActiveFieldFromParent()
        }
    }
    
    func updateActiveFieldFromParent() {
        if let field = currentActiveField {
            // Sett aktivt felt basert på hva forelderen sier
            if field.localizedCaseInsensitiveContains("tid") || field.localizedCaseInsensitiveContains("sek") {
                activeField = .time
            } else if field.localizedCaseInsensitiveContains("reps") {
                activeField = .reps
            } else if field.localizedCaseInsensitiveContains("vekt") || field.localizedCaseInsensitiveContains("kg") {
                activeField = .weight
            } else if field.localizedCaseInsensitiveContains("meter") {
                activeField = .distance
            }
            
            // --- VIKTIG: KOBLE OPP PICKEREN AUTOMATISK ---
            // Dette sørger for at stoppeklokken/linjalen faktisk styrer DENNE øvelsen
            // uten at du må trykke på knappen igjen.
            if let activeField = activeField {
                DispatchQueue.main.async {
                    restoreActivePickerBinding(for: activeField)
                }
            }
            // ---------------------------------------------
        } else {
            activeField = nil
        }
    }
    
    func restoreActivePickerBinding(for field: ActiveField) {
        switch field {
        case .time:
            onRequestPicker("Tid", $duration, 0...3600, 5)
        case .reps:
            onRequestPicker("Antall reps", $targetReps, 1...100, 1)
        case .weight:
            let weightBinding = Binding<Int>(
                get: { Int(weight) },
                set: { weight = Double($0) }
            )
            onRequestPicker("Vekt (kg)", weightBinding, 0...300, 1)
        case .distance:
            let distBinding = Binding<Int>(
                get: { Int(distance) },
                set: { distance = Double($0) }
            )
            onRequestPicker("Meter", distBinding, 0...10000, 50)
        default:
            break
        }
    }
    
    func applySmartDefaults() {
        switch selectedCategory {
        case .other:
            if name.isEmpty { name = "Pause" }
        default:
            if name == "Pause" { name = "" }
        }
    }
    
    func updateSegment() {
        if let segment = segmentToEdit {
            // Rutine-oppdatering
            if segment.name != name { segment.name = name }
            if segment.category != selectedCategory { segment.category = selectedCategory }
            if segment.note != note { segment.note = note }
            if segment.durationSeconds != duration { segment.durationSeconds = duration }
            if segment.targetReps != targetReps { segment.targetReps = targetReps }
            if segment.weight != weight { segment.weight = weight }
            if segment.distance != distance { segment.distance = distance }
        } else if let logEntry = logEntryToEdit {
            // Historikk-oppdatering
            if logEntry.originalReps == nil && logEntry.targetReps != targetReps {
                logEntry.originalReps = logEntry.targetReps
            }
            if logEntry.originalWeight == nil && logEntry.weight != weight {
                logEntry.originalWeight = logEntry.weight
            }
            if logEntry.originalDuration == nil && logEntry.durationSeconds != duration {
                logEntry.originalDuration = logEntry.durationSeconds
            }
            if logEntry.originalDistance == nil && logEntry.distance != distance {
                logEntry.originalDistance = logEntry.distance
            }
            
            logEntry.name = name
            logEntry.categoryRawValue = selectedCategory.rawValue
            logEntry.note = note
            logEntry.durationSeconds = duration
            logEntry.targetReps = targetReps
            logEntry.weight = weight
            logEntry.distance = distance
            
            log?.wasEdited = true
        }
    }
    
    func deleteSegment() {
        if let segment = segmentToEdit, let routine = routine {
            if let index = routine.segments.firstIndex(of: segment) {
                routine.segments.remove(at: index)
            }
            modelContext.delete(segment)
            onDismiss()
        } else if let logEntry = logEntryToEdit, let log = log {
            if let index = log.exercises.firstIndex(of: logEntry) {
                log.exercises.remove(at: index)
            }
            modelContext.delete(logEntry)
            onDismiss()
        }
    }
    
}
// Hjelper for å velge ikon til listen
    private func categoryIcon(for category: ExerciseCategory) -> String {
        switch category {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .combined: return "figure.mind.and.body" // Passer fint for Yoga/Balanse/Core
        case .other: return "star.fill"
        }
    }
    
// Hjelper for å velge farge til ikonet
    private func categoryColor(for category: ExerciseCategory) -> Color {
        switch category {
        case .strength: return .blue
        case .cardio: return .red
        case .combined: return .purple // Lilla passer godt til "Combined/Yoga"
        case .other: return .orange
        }
    }
// --- HJELPE-STRUCTS ---

struct CompactInputCell: View {
    let value: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                        .padding(.vertical, 16)
                }
                
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
    }
    
}
