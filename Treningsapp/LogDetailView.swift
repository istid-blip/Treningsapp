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
    
    // UI States for redigering (Samme logikk som før)
    @State private var activeDrawer: DrawerState? = nil
    @State private var activePicker: PickerState? = nil
    
    // Vi trenger en midlertidig "dummy" rutine for at AddSegmentView skal fungere,
    // selv om vi ikke lagrer til den.
    @State private var tempRoutine = CircuitRoutine(name: "Temp")
    
    // For å vite hvilken logg-rad vi redigerer
    @State private var editingLogExercise: LoggedExercise?
    
    let theme = AppTheme.standard
    let pickerHeight: CGFloat = 320
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                
                // --- BAKGRUNN ---
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
                            Text(log.routineName)
                                .font(.headline)
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        // Usynlig spacer for balanse
                        Color.clear.frame(width: 60, height: 44)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // STATUS BAR FOR REDIGERING
                    if log.wasEdited {
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                            Text("Denne økten er justert etter gjennomføring")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                    }
                    
                    // LISTE OVER UTFØRTE ØVELSER (Annerledes design enn planlegging)
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
                                        
                                        Text(descriptionText(for: exercise))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white)
                        }
                        .onDelete(perform: deleteExercise)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden) // Fjerner standard grå bakgrunn
                }
                
                // --- DIMMING ---
                if activeDrawer != nil || activePicker != nil {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { closeAllPanels() }
                        .transition(.opacity)
                        .zIndex(10)
                }
                
                // --- SKUFF (ADD SEGMENT VIEW) ---
                if let drawerState = activeDrawer {
                    let availableHeight = activePicker != nil
                        ? (geometry.size.height - pickerHeight)
                        : (geometry.size.height + 60)
                    
                    DrawerView(theme: theme, edge: .top, maxHeight: availableHeight) {
                        switch drawerState {
                        case .editSegment(let segment):
                            AddSegmentView(
                                routine: tempRoutine, // Dummy
                                segmentToEdit: segment,
                                onDismiss: { saveChangesAndClose(from: segment) },
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
    
    // --- LOGIKK ---
    
    func startEditing(_ exercise: LoggedExercise) {
        // 1. Lagre referanse til logg-objektet vi redigerer
        editingLogExercise = exercise
        
        // 2. Konverter LoggedExercise -> Temporary CircuitExercise
        // Dette gjør at vi kan gjenbruke AddSegmentView uten å endre koden der!
        let tempSegment = CircuitExercise(
            name: exercise.name,
            durationSeconds: exercise.durationSeconds,
            targetReps: exercise.targetReps,
            weight: exercise.weight,
            distance: exercise.distance,
            category: exercise.category,
            note: exercise.note
        )
        
        // 3. Åpne skuffen med det midlertidige objektet
        withAnimation(.snappy) {
            activeDrawer = .editSegment(tempSegment)
        }
    }
    
    func saveChangesAndClose(from tempSegment: CircuitExercise) {
        guard let originalExercise = editingLogExercise else { return }
        
        // 1. Sjekk om sletting ble trigget i AddSegmentView (hvis den ble fjernet fra tempRoutine)
        // (Enkelt triks: Vi kan legge til slette-logikk her hvis nødvendig, men swipe-to-delete dekker det meste)
        
        // 2. Kopier verdiene TILBAKE fra temp til logg
        originalExercise.name = tempSegment.name
        originalExercise.categoryRawValue = tempSegment.category.rawValue
        originalExercise.durationSeconds = tempSegment.durationSeconds
        originalExercise.targetReps = tempSegment.targetReps
        originalExercise.weight = tempSegment.weight
        originalExercise.distance = tempSegment.distance
        originalExercise.note = tempSegment.note
        
        // 3. Merk loggen som redigert
        log.wasEdited = true
        
        // 4. Lagre og lukk
        try? modelContext.save()
        closeAllPanels()
    }
    
    func deleteExercise(at offsets: IndexSet) {
        for index in offsets {
            let exercise = log.exercises[index]
            modelContext.delete(exercise)
        }
        log.wasEdited = true
        try? modelContext.save()
    }
    
    func closeAllPanels() {
        withAnimation(.snappy) {
            activeDrawer = nil
            activePicker = nil
        }
        editingLogExercise = nil
    }
    
    // Hjelpere for visning
    func iconName(for category: ExerciseCategory) -> String {
        switch category { case .strength: return "dumbbell.fill"; case .cardio: return "figure.run"; case .combined: return "figure.strengthtraining.functional"; case .other: return "timer" }
    }
    
    func descriptionText(for exercise: LoggedExercise) -> String {
        switch exercise.category {
        case .strength:
            let w = exercise.weight > 0 ? " @ \(Int(exercise.weight))kg" : ""
            return "\(exercise.targetReps) reps\(w)"
        case .cardio:
            let d = exercise.distance > 0 ? " (\(Int(exercise.distance)) m)" : ""
            return "\(exercise.durationSeconds) sek\(d)"
        case .other: return "\(exercise.durationSeconds) sek"
        case .combined: return "\(exercise.targetReps) reps / \(exercise.durationSeconds) sek"
        }
    }
}
