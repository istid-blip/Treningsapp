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
    let id = UUID()
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
