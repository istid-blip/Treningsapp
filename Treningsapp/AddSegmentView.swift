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
                    
                    // 2. KATEGORI (ENDRET: Ingen scrolling)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategori")
                            .font(.caption).foregroundStyle(.secondary)
                        
                        // HER ER ENDRINGEN: Fjernet ScrollView, lagt til maxWidth på knappene
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
                                        .lineLimit(1) // Sikrer at tekst holder seg på én linje
                                        .minimumScaleFactor(0.8) // Krymper teksten litt hvis det blir trangt
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity) // VIKTIG: Deler plassen likt
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
                    VStack(spacing: 16) {
                        
                        if showReps {
                            SmartInputRow(
                                title: "Antall Reps",
                                valueString: "\(targetReps)",
                                icon: "arrow.counterclockwise",
                                action: { onRequestPicker("Antall reps", $targetReps, 1...100, 1) }
                            )
                        }
                        
                        if showWeight {
                            SmartInputRow(
                                title: "Belastning (kg)",
                                valueString: weight == 0 ? "-" : String(format: "%.0f kg", weight),
                                icon: "scalemass",
                                action: {
                                    let weightBinding = Binding<Int>(
                                        get: { Int(weight) },
                                        set: { weight = Double($0); updateSegment() }
                                    )
                                    onRequestPicker("Vekt (kg)", weightBinding, 0...300, 1)
                                }
                            )
                        }
                        
                        if showTime {
                            SmartInputRow(
                                title: "Varighet",
                                valueString: "\(duration) sek",
                                icon: "clock",
                                action: { onRequestPicker("Tid (sek)", $duration, 5...600, 5) }
                            )
                        }
                        
                        if showDistance {
                            SmartInputRow(
                                title: "Distanse (meter)",
                                valueString: distance == 0 ? "-" : String(format: "%.0f m", distance),
                                icon: "figure.run",
                                action: {
                                    let distBinding = Binding<Int>(
                                        get: { Int(distance) },
                                        set: { distance = Double($0); updateSegment() }
                                    )
                                    onRequestPicker("Meter", distBinding, 0...10000, 50)
                                }
                            )
                        }
                    }
                    
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
        .onChange(of: duration) { _, _ in updateSegment() }
        .onChange(of: targetReps) { _, _ in updateSegment() }
        
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
        segment.name = name
        segment.category = selectedCategory
        segment.note = note
        segment.durationSeconds = duration
        segment.targetReps = targetReps
        segment.weight = weight
        segment.distance = distance
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

struct SmartInputRow: View {
    let title: String
    let valueString: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.caption).foregroundStyle(Color.blue)
                }
                
                Text(title).foregroundStyle(Color.primary)
                Spacer()
                HStack(spacing: 4) {
                    Text(valueString).font(.title3).bold().foregroundStyle(Color.primary)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8).background(Color(.systemGray6)).cornerRadius(8)
            }
            .padding(12).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.03), radius: 5)
        }
    }
}

