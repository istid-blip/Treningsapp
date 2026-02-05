import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Styrke"
    case cardio = "Kondisjon"
    case combined = "Kombinert"
    case other = "Annet"
}

enum SegmentType: String, Codable, CaseIterable {
    case duration = "Tid"
    case reps = "Repetisjoner"
    case stopwatch = "Stoppeklokke"
    case pause = "Pause"
}

@Model
final class CircuitRoutine {
    var name: String
    var createdDate: Date
    @Relationship(deleteRule: .cascade) var segments: [CircuitExercise] = []
    
    init(name: String) {
        self.name = name
        self.createdDate = Date()
    }
}

@Model
final class CircuitExercise {
    var name: String
    var durationSeconds: Int
    var targetReps: Int
    
    var categoryRawValue: String = ExerciseCategory.strength.rawValue
    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? .strength }
        set { categoryRawValue = newValue.rawValue }
    }
    
    var note: String
    var restSeconds: Int = 0
    var typeRawValue: String = SegmentType.duration.rawValue
    var type: SegmentType {
        get { SegmentType(rawValue: typeRawValue) ?? .duration }
        set { typeRawValue = newValue.rawValue }
    }
    
    // --- ENDRING: Nytt felt for å huske rekkefølgen ---
    var sortIndex: Int = 0
    
    init(name: String,
         durationSeconds: Int = 45,
         targetReps: Int = 10,
         category: ExerciseCategory = .strength,
         note: String = "",
         type: SegmentType = .duration,
         sortIndex: Int = 0) { // Tar inn sortIndex
        
        self.name = name
        self.durationSeconds = durationSeconds
        self.targetReps = targetReps
        self.categoryRawValue = category.rawValue
        self.note = note
        self.typeRawValue = type.rawValue
        self.sortIndex = sortIndex // Lagrer rekkefølgen
    }
}
