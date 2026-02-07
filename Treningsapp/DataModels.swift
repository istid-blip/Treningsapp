import Foundation
import SwiftData

// Endret .other tilbake til "Annet"
enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Styrke"
    case cardio = "Kondisjon"
    case combined = "Kombinert"
    case other = "Annet"
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
    
    // Standard data
    var durationSeconds: Int // Brukes for Kondisjon, Annet, Kombinert
    var targetReps: Int      // Brukes for Styrke, Kombinert
    
    // NYE FELTER (Valgfrie)
    var weight: Double = 0.0    // For styrke (kg)
    var distance: Double = 0.0  // For kondisjon (meter eller km)
    
    var categoryRawValue: String = ExerciseCategory.strength.rawValue
    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? .strength }
        set { categoryRawValue = newValue.rawValue }
    }
    
    var note: String
    var sortIndex: Int = 0
    
    init(name: String,
         durationSeconds: Int = 45,
         targetReps: Int = 10,
         weight: Double = 0.0,
         distance: Double = 0.0,
         category: ExerciseCategory = .strength,
         note: String = "",
         sortIndex: Int = 0) {
        
        self.name = name
        self.durationSeconds = durationSeconds
        self.targetReps = targetReps
        self.weight = weight
        self.distance = distance
        self.categoryRawValue = category.rawValue
        self.note = note
        self.sortIndex = sortIndex
    }
}
// ... (Din eksisterende kode for CircuitRoutine og CircuitExercise beholdes som den er) ...

// --- NYE MODELLER FOR HISTORIKK ---

// --- NYE MODELLER FOR HISTORIKK ---

@Model
final class WorkoutLog {
    var routineName: String
    var date: Date
    var wasEdited: Bool = false // Nytt felt: Viser om økten er endret i ettertid
    
    @Relationship(deleteRule: .cascade) var exercises: [LoggedExercise] = []
    
    init(routineName: String, date: Date = Date()) {
        self.routineName = routineName
        self.date = date
    }
}

@Model
final class LoggedExercise {
    var name: String
    var categoryRawValue: String
    
    // Vi lagrer NÅ rådataene også, slik at vi kan redigere dem
    var durationSeconds: Int
    var targetReps: Int
    var weight: Double
    var distance: Double
    var note: String
    
    init(name: String, categoryRawValue: String, duration: Int, reps: Int, weight: Double, distance: Double, note: String) {
        self.name = name
        self.categoryRawValue = categoryRawValue
        self.durationSeconds = duration
        self.targetReps = reps
        self.weight = weight
        self.distance = distance
        self.note = note
    }
    
    var category: ExerciseCategory {
        ExerciseCategory(rawValue: categoryRawValue) ?? .strength
    }
}
