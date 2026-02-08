//
//  TreningsappApp.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 04/02/2026.
//
import SwiftUI
import SwiftData

@main
struct TreningsappApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // HER ER ENDRINGEN: Vi må inkludere de nye logg-modellene
        .modelContainer(for: [
            CircuitRoutine.self,
            CircuitExercise.self,
            WorkoutLog.self,      // <--- Ny
            LoggedExercise.self   // <--- Ny
        ])
    }
}
