import SwiftUI
import SwiftData

struct AddSegmentView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    var routine: CircuitRoutine
    
    // Topp-nivå valg
    @State private var isPauseBlock = false
    
    // Felt for Øvelse
    @State private var name = ""
    
    // --- ENDRING: Bruker nå Enum som standardverdi ---
    @State private var selectedCategory: ExerciseCategory = .strength
    
    @State private var note = ""
    @State private var selectedType: SegmentType = .duration
    @State private var duration = 45
    @State private var targetReps = 10
    
    // Felt for Pause
    @State private var pauseDuration = 30
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. HVA VIL DU LEGGE TIL?
                Section {
                    Picker("Hva vil du legge til?", selection: $isPauseBlock) {
                        Text("Ny Øvelse").tag(false)
                        Text("Pause").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                
                if isPauseBlock {
                    // --- UI FOR PAUSE ---
                    Section(header: Text("Varighet")) {
                        Stepper("Pause: \(pauseDuration) sek", value: $pauseDuration, in: 5...600, step: 5)
                    }
                    
                } else {
                    // --- UI FOR ØVELSE ---
                    Section(header: Text("Info")) {
                        TextField("Navn på øvelse", text: $name)
                        
                        // --- ENDRING: Picker bruker nå Enum ---
                        Picker("Kategori", selection: $selectedCategory) {
                            // Filterer bort 'pause' fra menyen her, siden det er et eget valg øverst
                            ForEach(ExerciseCategory.allCases.filter { $0 != .pause }, id: \.self) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }
                    
                    Section(header: Text("Type og Mål")) {
                        Picker("Type", selection: $selectedType) {
                            Text("Tid (Nedtelling)").tag(SegmentType.duration)
                            Text("Repetisjoner").tag(SegmentType.reps)
                            Text("Stoppeklokke").tag(SegmentType.stopwatch)
                        }
                        
                        if selectedType == .duration {
                            Stepper("Tid: \(duration) sek", value: $duration, in: 10...300, step: 5)
                        } else if selectedType == .reps {
                            Stepper("Antall: \(targetReps) reps", value: $targetReps, in: 1...200, step: 1)
                        } else if selectedType == .stopwatch {
                            Stepper("Mål: \(targetReps) reps", value: $targetReps, in: 1...200, step: 1)
                        }
                    }
                    
                    Section(header: Text("Notater")) {
                        TextField("Instruksjoner...", text: $note)
                    }
                }
            }
            .navigationTitle(isPauseBlock ? "Legg til Pause" : "Ny Øvelse")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Legg til") {
                        saveSegment()
                    }
                    .disabled(!isPauseBlock && name.isEmpty)
                }
            }
        }
    }
    
    func saveSegment() {
        if routine.modelContext == nil { modelContext.insert(routine) }
        
        let newSegment: CircuitExercise
        
        if isPauseBlock {
            newSegment = CircuitExercise(
                name: "Pause",
                durationSeconds: pauseDuration,
                category: .pause, // Bruker .pause fra Enum
                type: .pause
            )
        } else {
            newSegment = CircuitExercise(
                name: name,
                durationSeconds: duration,
                targetReps: targetReps,
                category: selectedCategory, // Bruker valgt Enum
                note: note,
                type: selectedType
            )
        }
        
        routine.segments.append(newSegment)
        dismiss()
    }
}
