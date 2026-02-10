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
    
    @State private var name = ""
    @State private var selectedCategory: ExerciseCategory = .strength
    @State private var note = ""
    
    @State private var duration = 45
    @State private var targetReps = 10
    @State private var weight: Double = 0.0
    @State private var distance: Double = 0.0
    
    @State private var showDeleteConfirmation = false
    
    @FocusState private var isNameFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. NAVN
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Øvelsesnavn")
                            .font(.caption).foregroundStyle(.secondary)
                        
                        TextField("F.eks. Pause eller Knebøy", text: $name)
                            .font(.title3)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onChange(of: name) { _, _ in updateSegment() }
                            .onChange(of: isNameFocused) { _, focused in
                                if focused { onTyping() }
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
                                action: { onRequestPicker("Antall reps", $targetReps, 1...100, 1) }
                            )
                        }
                        
                        if showWeight {
                            CompactInputCell(
                                value: weight == 0 ? "-" : String(format: "%.0f", weight),
                                label: "kg",
                                action: {
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
                                value: "\(duration)",
                                label: "Sek",
                                action: { onRequestPicker("Tid (sek)", $duration, 5...600, 5) }
                            )
                        }
                        
                        if showDistance {
                            CompactInputCell(
                                value: distance == 0 ? "-" : String(format: "%.0f", distance),
                                label: "Meter",
                                action: {
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
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isNoteFocused)
                            .submitLabel(.done)
                            .onChange(of: note) { _, _ in updateSegment() }
                            .onChange(of: isNoteFocused) { _, focused in
                                if focused { onTyping() }
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
            if let segment = segmentToEdit {
                name = segment.name
                selectedCategory = segment.category
                note = segment.note
                duration = segment.durationSeconds
                targetReps = segment.targetReps
                weight = segment.weight
                distance = segment.distance
            }
        }
        // VIKTIG: Vi har lagt tilbake .onChange slik at LogDetailView fanger opp endringene
        // Siden VerticalRuler nå fikser haptics selv, er dette trygt igjen.
        .onChange(of: duration) { _, _ in updateSegment() }
        .onChange(of: targetReps) { _, _ in updateSegment() }
        .onChange(of: weight) { _, _ in updateSegment() }
        .onChange(of: distance) { _, _ in updateSegment() }
        
        .alert("Slett?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Slett", role: .destructive) { deleteSegment() }
        } message: {
            Text("Er du sikker på at du vil fjerne denne delen?")
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
        
        // Oppdaterer objektet direkte.
        // I LogDetailView er dette et midlertidig objekt (raskt).
        // I CircuitDetailView er dette databasen (litt tregere, men Ruleren håndterer det nå).
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
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Selve inndataboksen
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primary)
                        .padding(.vertical, 16)
                }
                
                // Benevning under boksen
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
    }
}
