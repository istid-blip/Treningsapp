//
//  LogDetailView.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 07/02/2026.
//
import SwiftUI
import SwiftData

struct LogDetailView: View {
    @Bindable var log: WorkoutLog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    // UI States
    @State private var activeDrawer: DrawerState? = nil
    @State private var activePicker: PickerState? = nil
    @State private var tempRoutine = CircuitRoutine(name: "Temp")
    @State private var editingLogExercise: LoggedExercise?
    
    let theme = AppTheme.standard
    let pickerHeight: CGFloat = 320
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // HEADER
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left").bold()
                                Text("Tilbake")
                            }
                        }
                        Spacer()
                        VStack {
                            Text(log.routineName).font(.headline)
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Color.clear.frame(width: 60, height: 44)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground)) // Oppdatert til systemfarge
                    
                    // STATUS BAR (Oppdatert tekst)
                    if log.wasEdited || log.editCount > 0 {
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                            Text("Loggføringen har \(log.editCount) justeringer")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                    }
                    
                    // LISTE
                    List {
                        ForEach(log.exercises) { exercise in
                            Button(action: { startEditing(exercise) }) {
                                HStack(spacing: 16) {
                                    // Ikon boks
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(theme.color(for: exercise.category).opacity(0.15))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: iconName(for: exercise.category))
                                            .foregroundStyle(theme.color(for: exercise.category))
                                            .font(.title3)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name.isEmpty ? exercise.categoryRawValue : exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        
                                        // Her kaller vi den nye visningen for detaljer
                                        DetailChangeView(exercise: exercise)
                                    }
                                    
                                    Spacer()
                                    
                                    // Viser blyant hvis denne spesifikke raden er endret
                                    if exercise.hasChanges {
                                        Image(systemName: "pencil.circle.fill")
                                            .foregroundStyle(.orange)
                                    } else {
                                        Image(systemName: "pencil")
                                            .foregroundStyle(.gray.opacity(0.3))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color(.secondarySystemGroupedBackground)) // Dark mode fix
                        }
                        .onDelete(perform: deleteExercise)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
                
                // --- DIMMING ---
                if activeDrawer != nil || activePicker != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeAllPanels() }
                        .transition(.opacity)
                        .zIndex(10)
                }
                
                // --- SKUFF ---
                if let drawerState = activeDrawer {
                    let availableHeight = activePicker != nil
                        ? (geometry.size.height - pickerHeight)
                        : (geometry.size.height + 60)
                    
                    DrawerView(theme: theme, edge: .top, maxHeight: availableHeight) {
                        switch drawerState {
                        case .editSegment(let segment):
                            AddSegmentView(
                                routine: tempRoutine,
                                segmentToEdit: segment,
                                onDismiss: { closeAllPanels() },
                                onRequestPicker: { title, binding, range, step in
                                    withAnimation(.snappy) {
                                        activePicker = PickerState(title: title, binding: binding, range: range, step: step)
                                    }
                                },
                                onTyping: { withAnimation(.snappy) { activePicker = nil } }
                            )
                        }
                    }
                    .zIndex(11)
                    .ignoresSafeArea(.all, edges: .top)
                }
                
                // --- PICKER ---
                if let pickerState = activePicker {
                    DrawerView(theme: theme, edge: .bottom, maxHeight: pickerHeight) {
                        VStack(spacing: 15) {
                            Text(pickerState.title).font(.headline).padding(.top, 10)
                            Picker("", selection: pickerState.binding) {
                                ForEach(Array(stride(from: pickerState.range.lowerBound, through: pickerState.range.upperBound, by: pickerState.step)), id: \.self) { value in
                                    Text("\(value)").tag(value)
                                }
                            }.pickerStyle(.wheel).frame(height: 150)
                            Button("Ferdig") { withAnimation(.snappy) { activePicker = nil } }
                                .padding().background(Color.blue).foregroundStyle(.white).cornerRadius(12)
                        }
                    }.zIndex(12)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // --- NY LOGIKK FOR LAGRING AV ENDRINGER ---
    
    func commitTempChanges(from tempSegment: CircuitExercise) {
        guard let exercise = editingLogExercise else { return }
        
        if tempSegment.isDeleted {
            // modelContext.delete(exercise) // Valgfritt
            return
        }

        // Bruk hjelpefunksjonen på alle feltene
        updateLogValue(&exercise.durationSeconds, &exercise.originalDuration, tempSegment.durationSeconds)
        updateLogValue(&exercise.targetReps, &exercise.originalReps, tempSegment.targetReps)
        updateLogValue(&exercise.weight, &exercise.originalWeight, tempSegment.weight)
        updateLogValue(&exercise.distance, &exercise.originalDistance, tempSegment.distance)

        // Oppdater tekst-feltene direkte (trenger ikke historikk på navn/kategori/notat)
        exercise.name = tempSegment.name
        exercise.categoryRawValue = tempSegment.category.rawValue
        exercise.note = tempSegment.note
        
        // VIKTIG: Sjekk om loggen faktisk har endringer igjen
        // Hvis brukeren har rettet alt tilbake til originalt, skal ikke loggen være markert som "Edited" lenger.
        log.wasEdited = log.exercises.contains { $0.hasChanges }
        
        try? modelContext.save()
    }
    
    func startEditing(_ exercise: LoggedExercise) {
        editingLogExercise = exercise
        let tempSegment = CircuitExercise(
            name: exercise.name,
            durationSeconds: exercise.durationSeconds,
            targetReps: exercise.targetReps,
            weight: exercise.weight,
            distance: exercise.distance,
            category: exercise.category,
            note: exercise.note
        )
        withAnimation(.snappy) { activeDrawer = .editSegment(tempSegment) }
    }
    
    // Hjelpefunksjon for å håndtere logikk for "angre" vs "endre"
    func updateLogValue<T: Equatable>(_ current: inout T, _ original: inout T?, _ newValue: T) {
        if let old = original {
            // Vi har allerede en endring lagret
            if newValue == old {
                // Verdien er satt tilbake til originalen -> Slett historikken
                current = newValue
                original = nil
            } else {
                // Verdien er endret til noe annet -> Oppdater nåverdi
                current = newValue
            }
        } else if newValue != current {
            // Første gang verdien endres
            original = current
            current = newValue
        }
    }
    
    func closeAllPanels() {
        if case .editSegment(let tempSegment) = activeDrawer {
            commitTempChanges(from: tempSegment)
        }
        withAnimation(.snappy) {
            activeDrawer = nil
            activePicker = nil
        }
        editingLogExercise = nil
    }
    
    func deleteExercise(at offsets: IndexSet) {
        for index in offsets {
            let exercise = log.exercises[index]
            modelContext.delete(exercise)
        }
        log.wasEdited = true
        try? modelContext.save()
    }
    
    func iconName(for category: ExerciseCategory) -> String {
        switch category { case .strength: return "dumbbell.fill"; case .cardio: return "figure.run"; case .combined: return "figure.strengthtraining.functional"; case .other: return "timer" }
    }
}

// --- NY KOMPONENT: Viser gammel vs ny verdi ---

struct DetailChangeView: View {
    let exercise: LoggedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            
            // Styrke / Kombinert / Reps
            if exercise.category == .strength || exercise.category == .combined {
                changeText(current: exercise.targetReps, original: exercise.originalReps, unit: "reps")
                changeText(current: exercise.weight, original: exercise.originalWeight, unit: "kg")
            }
            
            // Cardio / Annet / Tid
            if exercise.category == .cardio || exercise.category == .other || exercise.category == .combined {
                changeText(current: exercise.durationSeconds, original: exercise.originalDuration, unit: "sek")
            }
            
            // Distanse
            if exercise.category == .cardio {
                changeText(current: exercise.distance, original: exercise.originalDistance, unit: "m")
            }
        }
    }
    
    // Hjelper for Int (Reps/Tid)
    @ViewBuilder
    func changeText(current: Int, original: Int?, unit: String) -> some View {
        if let original = original, original != current {
            HStack(spacing: 4) {
                Text("\(original)")
                    .strikethrough()
                    .foregroundStyle(.red.opacity(0.8))
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(current) \(unit)")
                    .bold()
                    .foregroundStyle(.green) // Eller .primary om du vil ha det mer nøytralt
            }
            .font(.subheadline)
        } else if current > 0 {
            Text("\(current) \(unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // Hjelper for Double (Vekt/Distanse)
    @ViewBuilder
    func changeText(current: Double, original: Double?, unit: String) -> some View {
        if let original = original, original != current {
            HStack(spacing: 4) {
                Text("\(Int(original))")
                    .strikethrough()
                    .foregroundStyle(.red.opacity(0.8))
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(Int(current)) \(unit)")
                    .bold()
                    .foregroundStyle(.green)
            }
            .font(.subheadline)
        } else if current > 0 {
            Text("\(Int(current)) \(unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
