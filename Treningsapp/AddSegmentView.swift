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
    
    var onDismiss: () -> Void
    var onRequestPicker: (String, Binding<Int>, ClosedRange<Int>, Int) -> Void
    var onTyping: () -> Void
    
    // Callbacks
    var onSwitchSegment: ((CircuitExercise) -> Void)?
    var onSwitchLogEntry: ((LoggedExercise) -> Void)?
    
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
        log?.exercises ?? []
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
        
        .onChange(of: duration) { _, _ in updateSegment() }
        .onChange(of: targetReps) { _, _ in updateSegment() }
        .onChange(of: weight) { _, _ in updateSegment() }
        .onChange(of: distance) { _, _ in updateSegment() }
        
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
    
    // --- VIEW COMPONENTS (Splittet opp for å hjelpe kompilatoren) ---
    
    var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Øvelsesnavn")
                .font(.caption).foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // VENSTRE PIL
                Button(action: {
                    if let prev = previousSegment { onSwitchSegment?(prev) }
                    else if let prevLog = previousLogEntry { onSwitchLogEntry?(prevLog) }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundStyle(canGoBack ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemFill))
                        .clipShape(Circle())
                }
                .disabled(!canGoBack)
                
                // TEKSTFELT
                TextField("F.eks. Pause eller Knebøy", text: $name)
                    .font(.title3)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(activeField == .name ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(activeField == .name ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onChange(of: name) { _, _ in updateSegment() }
                    .onChange(of: isNameFocused) { _, focused in
                        if focused {
                            onTyping()
                            activeField = .name
                        }
                    }
                
                // HØYRE PIL
                Button(action: {
                    if let next = nextSegment { onSwitchSegment?(next) }
                    else if let nextLog = nextLogEntry { onSwitchLogEntry?(nextLog) }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3.bold())
                        .foregroundStyle(canGoForward ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemFill))
                        .clipShape(Circle())
                }
                .disabled(!canGoForward)
            }
        }
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
    
    func loadData() {
        if let segment = segmentToEdit {
            name = segment.name
            selectedCategory = segment.category
            note = segment.note
            duration = segment.durationSeconds
            targetReps = segment.targetReps
            weight = segment.weight
            distance = segment.distance
            activeField = nil
        } else if let logEntry = logEntryToEdit {
            name = logEntry.name
            selectedCategory = logEntry.category
            note = logEntry.note
            duration = logEntry.durationSeconds
            targetReps = logEntry.targetReps
            weight = logEntry.weight
            distance = logEntry.distance
            activeField = nil
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

// --- HJELPE-STRUCTS (DISSE MANGLER I FORRIGE VERSJON) ---

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
