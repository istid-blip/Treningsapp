//
//  LogDetailView.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 04/02/2026.
//

import SwiftUI
import SwiftData

struct LogDetailView: View {
    let log: WorkoutLog
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(log.routineName)
                                .font(.title)
                                .bold()
                            Spacer()
                            // Datoikon
                            VStack {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                Text(log.date.formatted(.dateTime.day().month()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // --- NYTT: Visning av total tid ---
                        if log.totalDuration > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.gray)
                                Text("Total tid:")
                                    .foregroundStyle(.secondary)
                                Text(formatTid(log.totalDuration))
                                    .bold()
                                    .foregroundStyle(.blue)
                            }
                            .font(.subheadline)
                            .padding(.top, 2)
                        }
                        // ---------------------------------
                    }
                    .padding(.vertical, 5)
                }
                
                Section("Gjennomførte øvelser") {
                    ForEach(log.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(exercise.name)
                                    .font(.headline)
                                Spacer()
                                Text(exercise.category.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.standard.color(for: exercise.category).opacity(0.2))
                                    .foregroundStyle(AppTheme.standard.color(for: exercise.category))
                                    .clipShape(Capsule())
                            }
                            
                            HStack {
                                Text(detailString(for: exercise))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if exercise.hasChanges {
                                    Spacer()
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .help("Redigert i ettertid")
                                }
                            }
                            
                            if !exercise.note.isEmpty {
                                Text(exercise.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Oppsummering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
        }
    }
    
    // Hjelpefunksjon for å vise detaljer
    func detailString(for exercise: LoggedExercise) -> String {
        var parts: [String] = []
        
        switch exercise.category {
        case .strength:
            if exercise.targetReps > 0 { parts.append("\(exercise.targetReps) reps") }
            if exercise.weight > 0 { parts.append("\(Int(exercise.weight)) kg") }
        case .cardio:
            if exercise.durationSeconds > 0 { parts.append(formatTid(exercise.durationSeconds)) }
            if exercise.distance > 0 { parts.append("\(Int(exercise.distance)) m") }
        case .combined:
            if exercise.targetReps > 0 { parts.append("\(exercise.targetReps) reps") }
            if exercise.weight > 0 { parts.append("\(Int(exercise.weight)) kg") }
            if exercise.durationSeconds > 0 { parts.append(formatTid(exercise.durationSeconds)) }
        case .other:
            if exercise.durationSeconds > 0 { parts.append(formatTid(exercise.durationSeconds)) }
        }
        
        return parts.joined(separator: " • ")
    }
    
    // Gjenbruker samme formateringslogikk
    func formatTid(_ sekunder: Int) -> String {
        if sekunder >= 60 {
            let min = sekunder / 60
            let sek = sekunder % 60
            return String(format: "%d:%02d min", min, sek)
        } else {
            return "\(sekunder) sek"
        }
    }
}
