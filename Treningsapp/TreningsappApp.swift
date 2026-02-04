//
//  TreningsappApp.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 04/02/2026.
//

import SwiftUI
import SwiftData

@main
struct TreningsappApp: App { // Bytt navn til det prosjektet ditt heter
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CircuitRoutine.self)
    }
}
