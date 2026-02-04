//
//  Item.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 04/02/2026.
//

import Foundation
import SwiftData

enum SegmentType: String, Codable, CaseIterable {
    case duration = "Tid"           // Jobb på tid
    case reps = "Repetisjoner"      // Jobb på antall
    case stopwatch = "Stoppeklokke" // Jobb på tid (oppover)
    case pause = "Pause"            // NY: Eget segment for hvile
}

@Model
final class CircuitRoutine {
    var name: String
    var createdDate: Date
    // Vi kaller relasjonen 'segments' nå, selv om klassen heter CircuitExercise under panseret
    @Relationship(deleteRule: .cascade) var segments: [CircuitExercise] = []
    
    init(name: String) {
        self.name = name
        self.createdDate = Date()
    }
}

@Model
final class CircuitExercise {
    var name: String
    var durationSeconds: Int // Brukes for "Tid" og "Pause"
    var targetReps: Int      // Brukes for "Reps" og "Stoppeklokke"
    var category: String     // For fargekoding
    var note: String
    
    // Vi fjerner 'restSeconds' herfra logisk sett, siden pause nå er et eget segment
    // Men vi lar feltet ligge for å ikke kræsje databasen unødig, men vi bruker det ikke.
    var restSeconds: Int = 0

    var typeRawValue: String = SegmentType.duration.rawValue
    
    var type: SegmentType {
        get { SegmentType(rawValue: typeRawValue) ?? .duration }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(name: String, durationSeconds: Int = 45, targetReps: Int = 10, category: String = "Styrke", note: String = "", type: SegmentType = .duration) {
        self.name = name
        self.durationSeconds = durationSeconds
        self.targetReps = targetReps
        self.category = category
        self.note = note
        self.typeRawValue = type.rawValue
    }
}
