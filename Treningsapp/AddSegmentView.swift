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
    
    var routine: CircuitRoutine
    var segmentToEdit: CircuitExercise?
    
    var onDismiss: () -> Void
    var onRequestPicker: (String, Binding<Int>, ClosedRange<Int>, Int) -> Void
    var onTyping: () -> Void
    
    // Callbacks
    var onSwitchSegment: ((CircuitExercise) -> Void)?
    var onStartTimer: ((Int) -> Void)? // <--- NY: Callback for å starte timer
    
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
    
    // Hjelpere for navigasjon
    private var sortedSegments: [CircuitExercise] {
        routine.segments.sorted { $0.sortIndex < $1.sortIndex }
    }
    
    private var previousSegment: CircuitExercise? {
        guard let current = segmentToEdit,
              let index = sortedSegments.firstIndex(of: current) else { return nil }
        return index > 0 ? sortedSegments[index - 1] : nil
    }
    
    private var nextSegment: CircuitExercise? {
        guard let current = segmentToEdit,
              let index = sortedSegments.firstIndex(of: current) else { return nil }
        return index < sortedSegments.count - 1 ? sortedSegments[index + 1] : nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. NAVN MED PILER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Øvelsesnavn")
                            .font(.caption).foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            // VENSTRE PIL (Forrige)
                            Button(action: {
                                if let prev = previousSegment { onSwitchSegment?(prev) }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3.bold())
                                    .foregroundStyle(previousSegment != nil ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .background(Color(.secondarySystemFill))
                                    .clipShape(Circle())
                            }
                            .disabled(previousSegment == nil)
                            
                            // SELVE TEKSTFELTET
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
                            
                            // HØYRE PIL (Neste)
                            Button(action: {
                                if let next = nextSegment { onSwitchSegment?(next) }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title3.bold())
                                    .foregroundStyle(nextSegment != nil ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .background(Color(.secondarySystemFill))
                                    .clipShape(Circle())
                            }
                            .disabled(nextSegment == nil)
                        }
                    }
                    
                    
                    // 2. KATEGORI
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
                    
                    // 3. SMARTE INNDATAFELT
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
                            // Tidsvelger
                            // Tidsvelger
                            CompactInputCell(
                                // Viser tid formatert (eks: 1:00) eller bare sekunder hvis under minuttet
                                value: duration >= 60 ? String(format: "%d:%02d", duration / 60, duration % 60) : "\(duration)",
                                label: "Tid", // Endret fra "Sek"
                                isActive: activeField == .time,
                                action: {
                                    activeField = .time
                                    onRequestPicker("Tid", $duration, 0...3600, 5) // Utvidet range, starter på 0
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
                    .padding(.horizontal)
                    
                    // 4. NOTATER
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
                    
                    Spacer(minLength: 20)
                    
                    // SLETT
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
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: segmentToEdit) { _, _ in
            loadData()
        }
        
        .onChange(of: duration) { _, _ in updateSegment() }
        .onChange(of: targetReps) { _, _ in updateSegment() }
        .onChange(of: weight) { _, _ in updateSegment() }
        .onChange(of: distance) { _, _ in updateSegment() }
        
        // Lukker tastaturet hvis man bytter til knappene (reps/vekt etc.)
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
    
    func loadData() {
        if let segment = segmentToEdit {
            name = segment.name
            selectedCategory = segment.category
            note = segment.note
            duration = segment.durationSeconds
            targetReps = segment.targetReps
            weight = segment.weight
            distance = segment.distance
            
            // Tilbakestill aktivt felt ved bytte av øvelse
            activeField = nil
        }
    }
    
    var showReps: Bool { selectedCategory == .strength || selectedCategory == .combined }
    var showWeight: Bool { selectedCategory == .strength || selectedCategory == .combined }
    var showTime: Bool { selectedCategory == .cardio || selectedCategory == .other || selectedCategory == .combined }
    var showDistance: Bool { selectedCategory == .cardio || selectedCategory == .combined }
    
    func applySmartDefaults() {
        switch selectedCategory {
        case .other:
            if name.isEmpty { name = "Pause" }
        default:
            if name == "Pause" { name = "" }
        }
    }
    
    func updateSegment() {
        guard let segment = segmentToEdit else { return }
        
        if segment.name != name { segment.name = name }
        if segment.category != selectedCategory { segment.category = selectedCategory }
        if segment.note != note { segment.note = note }
        if segment.durationSeconds != duration { segment.durationSeconds = duration }
        if segment.targetReps != targetReps { segment.targetReps = targetReps }
        if segment.weight != weight { segment.weight = weight }
        if segment.distance != distance { segment.distance = distance }
    }
    
    func deleteSegment() {
        guard let segment = segmentToEdit else { return }
        if let index = routine.segments.firstIndex(of: segment) {
            routine.segments.remove(at: index)
        }
        modelContext.delete(segment)
        onDismiss()
    }
}

struct CompactInputCell: View {
    let value: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Selve inndataboksen
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        // Liten fargeendring i bakgrunnen hvis aktiv
                        .fill(isActive ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        // Legger til en tydelig ramme (border) hvis aktiv
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        // Farger teksten blå (accent) hvis aktiv
                        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                        .padding(.vertical, 16)
                }
                
                // Benevning under boksen
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
