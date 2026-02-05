//
//  DataModels.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 04/02/2026.
//

import Foundation
import SwiftData

// --- ENDRING: Ny Enum for Kategori ---
// Dette sikrer at vi bruker faste verdier overalt i stedet for løse tekster.
enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Styrke"
    case cardio = "Kondisjon"
    case mobility = "Mobilitet"
    case core = "Core"
    case pause = "Pause" // Praktisk å ha pause som en kategori også
}

enum SegmentType: String, Codable, CaseIterable {
    case duration = "Tid"           // Jobb på tid
    case reps = "Repetisjoner"      // Jobb på antall
    case stopwatch = "Stoppeklokke" // Jobb på tid (oppover)
    case pause = "Pause"            // Eget segment for hvile
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
    
    // --- ENDRING: Kategori-logikk ---
    // Vi lagrer rawValue (strengen) i basen, men jobber med enumen i koden.
    var categoryRawValue: String = ExerciseCategory.strength.rawValue
    
    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? .strength }
        set { categoryRawValue = newValue.rawValue }
    }
    
    var note: String
    
    // Legacy-felt (kan fjernes senere hvis du wiper databasen, men trygt å la stå)
    var restSeconds: Int = 0

    var typeRawValue: String = SegmentType.duration.rawValue
    
    var type: SegmentType {
        get { SegmentType(rawValue: typeRawValue) ?? .duration }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(name: String,
         durationSeconds: Int = 45,
         targetReps: Int = 10,
         category: ExerciseCategory = .strength, // Tar nå inn Enum
         note: String = "",
         type: SegmentType = .duration) {
        
        self.name = name
        self.durationSeconds = durationSeconds
        self.targetReps = targetReps
        self.categoryRawValue = category.rawValue // Lagrer streng-verdien
        self.note = note
        self.typeRawValue = type.rawValue
    }
}
