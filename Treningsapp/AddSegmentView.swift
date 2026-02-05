import SwiftUI
import SwiftData

struct AddSegmentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    var routine: CircuitRoutine
    var segmentToEdit: CircuitExercise?
    
    // UI-tilstander
    @State private var name = ""
    @State private var selectedCategory: ExerciseCategory = .strength
    @State private var note = ""
    @State private var selectedType: SegmentType = .duration
    @State private var duration = 45
    @State private var targetReps = 10
    
    @State private var showDeleteConfirmation = false
    
    var isEditing: Bool { segmentToEdit != nil }
    
    let categoryColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // --- NAVN ---
                Section {
                    TextField("Navn på segment", text: $name)
                        .font(.title2)
                        .bold()
                        .submitLabel(.done)
                } header: {
                    Text("Navn")
                }
                
                // --- KATEGORI ---
                Section {
                    LazyVGrid(columns: categoryColumns, spacing: 12) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == category ? .bold : .regular)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Velg Kategori")
                }
                
                // --- TYPE OG MÅL ---
                Section(header: Text("Type og Mål")) {
                    Picker("Måles i", selection: $selectedType) {
                        Text("Tid").tag(SegmentType.duration)
                        Text("Reps").tag(SegmentType.reps)
                        Text("Stoppeklokke").tag(SegmentType.stopwatch)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    
                    if selectedType == .duration {
                        Stepper("Varighet: \(duration) sek", value: $duration, in: 5...600, step: 5)
                    } else if selectedType == .reps {
                        Stepper("Antall: \(targetReps) reps", value: $targetReps, in: 1...200, step: 1)
                    } else if selectedType == .stopwatch {
                        Stepper("Mål: \(targetReps) reps", value: $targetReps, in: 1...200, step: 1)
                    }
                }
                
                // --- NOTATER ---
                Section(header: Text("Notater")) {
                    TextField("Instruksjoner eller tips...", text: $note)
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack { Spacer(); Text("Slett Segment"); Spacer() }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Rediger" : "Nytt segment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Lagre" : "Legg til") { saveSegment() }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let segment = segmentToEdit {
                    setupForEditing(segment)
                } else {
                    // Ved NYTT segment: Hent forrige valg eller sett standard
                    loadLastUsedSettings()
                    
                    if name.isEmpty {
                        let uniqueCount = Set(routine.segments).count
                        name = "Segment \(uniqueCount + 1)"
                    }
                }
            }
            .alert("Slett segment?", isPresented: $showDeleteConfirmation) {
                Button("Slett", role: .destructive) { deleteSegment() }
                Button("Avbryt", role: .cancel) { }
            } message: {
                Text("Er du sikker på at du vil slette dette?")
            }
        }
    }
    
    // --- HJELPEFUNKSJONER ---
    
    func setupForEditing(_ segment: CircuitExercise) {
        name = segment.name
        selectedCategory = segment.category
        note = segment.note
        selectedType = segment.type
        duration = segment.durationSeconds
        targetReps = segment.targetReps
    }

    // Henter siste brukte innstillinger fra minnet
    func loadLastUsedSettings() {
        if let lastCat = UserDefaults.standard.string(forKey: "lastCategory"),
           let category = ExerciseCategory(rawValue: lastCat) {
            selectedCategory = category
        }
        
        if let lastType = UserDefaults.standard.string(forKey: "lastType"),
           let type = SegmentType(rawValue: lastType) {
            selectedType = type
        }
        
        let lastDuration = UserDefaults.standard.integer(forKey: "lastDuration")
        if lastDuration > 0 { duration = lastDuration }
        
        let lastReps = UserDefaults.standard.integer(forKey: "lastReps")
        if lastReps > 0 { targetReps = lastReps }
    }

    // Lagrer innstillingene til minnet
    func saveCurrentSettingsAsDefault() {
        UserDefaults.standard.set(selectedCategory.rawValue, forKey: "lastCategory")
        UserDefaults.standard.set(selectedType.rawValue, forKey: "lastType")
        UserDefaults.standard.set(duration, forKey: "lastDuration")
        UserDefaults.standard.set(targetReps, forKey: "lastReps")
    }
    
    func saveSegment() {
        if routine.modelContext == nil { modelContext.insert(routine) }
        
        // Lagre valgene som standard for NESTE gang (kun hvis vi ikke redigerer)
        if !isEditing {
            saveCurrentSettingsAsDefault()
        }
        
        if let segment = segmentToEdit {
            segment.name = name
            segment.durationSeconds = duration
            segment.targetReps = targetReps
            segment.category = selectedCategory
            segment.note = note
            segment.type = selectedType
        } else {
            let nextIndex = routine.segments.count
            let newSegment = CircuitExercise(
                name: name,
                durationSeconds: duration,
                targetReps: targetReps,
                category: selectedCategory,
                note: note,
                type: selectedType,
                sortIndex: nextIndex
            )
            routine.segments.append(newSegment)
        }
        dismiss()
    }
    
    func deleteSegment() {
        guard let segment = segmentToEdit else { return }
        if let index = routine.segments.firstIndex(of: segment) {
            routine.segments.remove(at: index)
        }
        modelContext.delete(segment)
        dismiss()
    }
}
