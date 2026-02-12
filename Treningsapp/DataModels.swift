//
//  DataModels.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 04/02/2026.
//
import Foundation
import SwiftData

// Enum for treningskategorier
enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Styrke"
    case cardio = "Kondisjon"
    case combined = "Kombinert"
    case other = "Annet"
}

// Hovedmodellen for en Økt (Routine)
@Model
final class CircuitRoutine {
    var name: String
    var createdDate: Date
    var sortIndex: Int = 0 // Holder orden på rekkefølgen på forsiden
    
    @Relationship(deleteRule: .cascade) var segments: [CircuitExercise] = []
    
    init(name: String) {
        self.name = name
        self.createdDate = Date()
        self.sortIndex = 0
    }
}

// Modellen for en enkelt øvelse i en økt
@Model
final class CircuitExercise {
    var name: String
    
    // Verdier
    var durationSeconds: Int
    var targetReps: Int
    var weight: Double
    var distance: Double
    
    var categoryRawValue: String
    var note: String
    var sortIndex: Int = 0 // Holder orden på rekkefølgen innad i økten
    
    // Hjelpevariabel for enum
    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? .strength }
        set { categoryRawValue = newValue.rawValue }
    }
    
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

// Modellen for en fullført treningslogg
@Model
final class WorkoutLog {
    var routineName: String
    var date: Date
    var totalDuration: Int = 0 // <--- NY: Lagrer total tid i sekunder
    var wasEdited: Bool = false
    
    @Relationship(deleteRule: .cascade) var exercises: [LoggedExercise] = []
    
    // Hjelper: Hvor mange øvelser er endret i ettertid?
    var editCount: Int {
        exercises.filter { $0.hasChanges }.count
    }
    
    init(routineName: String, date: Date = Date(), totalDuration: Int = 0) {
        self.routineName = routineName
        self.date = date
        self.totalDuration = totalDuration
    }
}

// Modellen for en utført øvelse (med historikk for endringer)
@Model
final class LoggedExercise {
    var name: String
    var categoryRawValue: String
    
    // Gjeldende verdier
    var durationSeconds: Int
    var targetReps: Int
    var weight: Double
    var distance: Double
    var note: String
    
    // Originale verdier (hvis endret i ettertid)
    var originalDuration: Int?
    var originalReps: Int?
    var originalWeight: Double?
    var originalDistance: Double?
    
    // Sjekker om øvelsen er redigert
    var hasChanges: Bool {
        originalDuration != nil || originalReps != nil || originalWeight != nil || originalDistance != nil
    }
    
    var category: ExerciseCategory {
        ExerciseCategory(rawValue: categoryRawValue) ?? .strength
    }
    
    init(name: String, categoryRawValue: String, duration: Int, reps: Int, weight: Double, distance: Double, note: String) {
        self.name = name
        self.categoryRawValue = categoryRawValue
        self.durationSeconds = duration
        self.targetReps = reps
        self.weight = weight
        self.distance = distance
        self.note = note
    }
}
func formatTid(_ sekunder: Int) -> String {
    if sekunder >= 60 {
        let min = sekunder / 60
        let sek = sekunder % 60
        return String(format: "%d:%02d min", min, sek)
    } else {
        return "\(sekunder) sek"
    }
}
