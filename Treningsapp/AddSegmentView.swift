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
    @State private var category = "Styrke"
    @State private var note = ""
    @State private var selectedType: SegmentType = .duration
    @State private var duration = 45
    @State private var targetReps = 10
    
    // Felt for Pause
    @State private var pauseDuration = 30
    
    let categories = ["Styrke", "Kondisjon", "Mobilitet", "Core"]
    
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
                        Picker("Kategori", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                    }
                    
                    Section(header: Text("Type og Mål")) {
                        Picker("Type", selection: $selectedType) {
                            // Vi filtrerer bort 'pause' fra denne listen, siden det velges på toppen
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
                    // Deaktiver knapp kun hvis det er øvelse og navn mangler
                    .disabled(!isPauseBlock && name.isEmpty)
                }
            }
        }
    }
    
    func saveSegment() {
        if routine.modelContext == nil { modelContext.insert(routine) }
        
        let newSegment: CircuitExercise
        
        if isPauseBlock {
            // Lag et PAUSE-segment
            newSegment = CircuitExercise(
                name: "Pause",
                durationSeconds: pauseDuration,
                category: "Pause", // Egen kategori for pause
                type: .pause
            )
        } else {
            // Lag et ØVELSE-segment
            newSegment = CircuitExercise(
                name: name,
                durationSeconds: duration,
                targetReps: targetReps,
                category: category,
                note: note,
                type: selectedType
            )
        }
        
        routine.segments.append(newSegment)
        dismiss()
    }
}
