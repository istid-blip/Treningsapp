import SwiftUI
import SwiftData

// MARK: - Enums & Structs for UI State

enum DrawerState: Identifiable {
    case editSegment(CircuitExercise)
    var id: String {
        switch self {
        case .editSegment(let segment): return "edit-\(segment.persistentModelID)"
        }
    }
}

struct PickerState: Identifiable {
    let id = "FastSkuffID"
    let title: String
    let binding: Binding<Int>
    let range: ClosedRange<Int>
    let step: Int
    
    var isTimePicker: Bool {
        title.lowercased().contains("tid") || title.lowercased().contains("sek")
    }
}

// MARK: - Drop Delegate
struct GridDropDelegate: DropDelegate {
    let item: CircuitExercise
    @Binding var items: [CircuitExercise]
    @Binding var draggingItem: CircuitExercise?
    var onSave: () -> Void
    
    func dropUpdated(info: DropInfo) -> DropProposal? { return DropProposal(operation: .move) }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        onSave()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        if draggingItem.id != item.id {
            guard let fromIndex = items.firstIndex(of: draggingItem),
                  let toIndex = items.firstIndex(of: item) else { return }
            
            withAnimation(.snappy) {
                items.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}

// MARK: - Styles
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Helper Functions
func segmentDescription(for segment: CircuitExercise) -> String {
    var linjer: [String] = []
    
    switch segment.category {
    case .strength:
        if segment.targetReps > 0 {
            if segment.weight > 0 {
                linjer.append("\(segment.targetReps) x \(Int(segment.weight)) kg")
            } else {
                linjer.append("\(segment.targetReps) reps")
            }
        } else if segment.weight > 0 {
            linjer.append("\(Int(segment.weight)) kg")
        }
    case .cardio:
        // Her brukes nå formatTid fra DataModels.swift automatisk
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
        if segment.distance > 0 { linjer.append("\(Int(segment.distance)) m") }
    case .combined:
        if segment.targetReps > 0 { linjer.append("\(segment.targetReps) reps") }
        if segment.weight > 0 { linjer.append("\(Int(segment.weight)) kg") }
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
        if segment.distance > 0 { linjer.append("\(Int(segment.distance)) m") }
    case .other:
        if segment.durationSeconds > 0 { linjer.append(formatTid(segment.durationSeconds)) }
    }
    return linjer.isEmpty ? "-" : linjer.joined(separator: "\n")
}

func iconForSegment(_ segment: CircuitExercise) -> String? {
    switch segment.category {
    case .strength: return "dumbbell.fill"
    case .cardio: return "figure.run"
    case .combined: return "figure.strengthtraining.functional"
    case .other: return "timer"
    }
}

// Ny struktur for å definere maler for øvelser (Pass på at du har denne!)
struct ExerciseTemplate {
    let name: String
    let category: ExerciseCategory
    
    // Hvilke felt skal vises?
    var showReps: Bool = false
    var showWeight: Bool = false
    var showTime: Bool = false
    var showDistance: Bool = false
    var showHeartRate: Bool = false
}

// Utvidet liste over standardøvelser tilgjengelig for hele appen
let standardExercises: [ExerciseTemplate] = [
    // --- STYRKE ---
    ExerciseTemplate(name: "Knebøy", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Benkpress", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Markløft", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Pushups", category: .strength, showReps: true, showWeight: false),
    ExerciseTemplate(name: "Pullups", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Utfall", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Skulderpress", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Bicepscurl", category: .strength, showReps: true, showWeight: true),
    ExerciseTemplate(name: "Nedtrekk", category: .strength, showReps: true, showWeight: true),
    
    // --- KARDIO ---
    ExerciseTemplate(name: "Løping", category: .cardio, showTime: true, showDistance: true, showHeartRate: true),
    ExerciseTemplate(name: "Sykling", category: .cardio, showTime: true, showDistance: true, showHeartRate: true),
    ExerciseTemplate(name: "Roing", category: .cardio, showTime: true, showDistance: true, showHeartRate: true),
    ExerciseTemplate(name: "Gåtur", category: .cardio, showTime: true, showDistance: true, showHeartRate: true),
    ExerciseTemplate(name: "Trappemaskin", category: .cardio, showTime: true, showHeartRate: true),
    
    // --- KOMBINERT / ANNET ---
    ExerciseTemplate(name: "Planken", category: .combined, showTime: true),
    ExerciseTemplate(name: "Situps", category: .combined, showReps: true),
    ExerciseTemplate(name: "Burpees", category: .combined, showReps: true, showTime: true),
    ExerciseTemplate(name: "Yoga", category: .combined, showTime: true, showHeartRate: true),
    ExerciseTemplate(name: "Stretching", category: .combined, showTime: true)
]

// Generell funksjon for å hente ikon basert på kategori
func iconForCategory(_ category: ExerciseCategory) -> String {
    switch category {
    case .strength: return "dumbbell.fill"
    case .cardio: return "figure.run"
    case .combined: return "figure.mind.and.body"
    case .other: return "star.fill"
    }
}
