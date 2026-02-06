//
//  AppTheme.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 06/02/2026.
//
import SwiftUI

struct AppTheme {
    let name: String
    
    // Pil-innstillinger
    let arrowIcon: String
    let arrowColor: Color
    
    // Generelle farger
    let textColor: Color
    let backgroundColor: Color // Hvis du vil ha tema på bakgrunnen også
    
    // Funksjon for å hente farge basert på kategori
    func color(for category: ExerciseCategory) -> Color {
        switch name {
        case "Standard":
            switch category {
            case .strength: return .blue
            case .cardio: return .red
            case .combined: return .purple
            case .other: return .gray
            }
        case "Dark Mode":
            // Eksempel på et annet fargekart
            switch category {
            case .strength: return Color(.blue) // En mørkere blå
            case .cardio: return Color(.red)   // En mørkere rød
            case .combined: return .indigo
            case .other: return .gray.opacity(0.5)
            }
        default:
            return .blue
        }
    }
}

// Her lager vi ferdige temaer som vi kan bruke
extension AppTheme {
    static let standard = AppTheme(
        name: "Standard",
        arrowIcon: "arrow.right",
        arrowColor: .gray.opacity(0.6),
        textColor: .white,
        backgroundColor: .white
    )
    
    static let minimal = AppTheme(
        name: "Minimal",
        arrowIcon: "chevron.right", // En tynnere pil
        arrowColor: .black,
        textColor: .black,
        backgroundColor: Color(.systemGray6)
    )
}
