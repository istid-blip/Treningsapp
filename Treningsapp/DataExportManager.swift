//
//  DataExportManager.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 22/02/2026.
//
import Foundation
import SwiftData

// Felles struktur for hele backupen
struct ExportPayload: Codable {
    let routines: [ExportRoutine]
    let logs: [ExportLog]
}

// Strukturer for Programmene (CircuitRoutine)
struct ExportRoutine: Codable {
    let name: String
    let createdDate: Date
    let sortIndex: Int
    let segments: [ExportSegment]
}

struct ExportSegment: Codable {
    let name: String
    let durationSeconds: Double
    let targetReps: Int
    let weight: Double
    let distance: Double
    let categoryRawValue: String
    let note: String
    let sortIndex: Int
}

// Strukturer for Loggene (WorkoutLog)
struct ExportLog: Codable {
    let routineName: String
    let date: Date
    let totalDuration: Int
    let exercises: [ExportExercise]
}

struct ExportExercise: Codable {
    let name: String
    let category: String
    let duration: Double
    let reps: Int
    let weight: Double
    let distance: Double
    let note: String
}

struct DataExportManager {
    
    // Eksport: Bygger JSON for både programmer og logger
    static func generateJSON(routines: [CircuitRoutine], logs: [WorkoutLog]) -> URL? {
        let exportRoutines = routines.map { r in
            ExportRoutine(
                name: r.name,
                createdDate: r.createdDate,
                sortIndex: r.sortIndex,
                segments: r.segments.map { s in
                    ExportSegment(name: s.name, durationSeconds: s.durationSeconds, targetReps: s.targetReps, weight: s.weight, distance: s.distance, categoryRawValue: s.categoryRawValue, note: s.note, sortIndex: s.sortIndex)
                }
            )
        }
        
        let exportLogs = logs.map { log in
            ExportLog(
                routineName: log.routineName,
                date: log.date,
                totalDuration: log.totalDuration,
                exercises: log.exercises.map { ex in
                    ExportExercise(name: ex.name, category: ex.categoryRawValue, duration: ex.durationSeconds, reps: ex.targetReps, weight: ex.weight, distance: ex.distance, note: ex.note)
                }
            )
        }
        
        let payload = ExportPayload(routines: exportRoutines, logs: exportLogs)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(payload)
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Treningsdata_Komplett.json")
            try data.write(to: url)
            return url
        } catch {
            print("Feil ved generering av JSON: \(error)")
            return nil
        }
    }
    
    // Import: Leser JSON og lagrer i SwiftData
    static func importJSON(from url: URL, context: ModelContext) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let payload = try decoder.decode(ExportPayload.self, from: data)
        
        // Gjenopprett programmer
        for r in payload.routines {
            let nyRoutine = CircuitRoutine(name: r.name)
            nyRoutine.createdDate = r.createdDate
            nyRoutine.sortIndex = r.sortIndex
            
            for s in r.segments {
                let nySegment = CircuitExercise(name: s.name, durationSeconds: s.durationSeconds, targetReps: s.targetReps, weight: s.weight, distance: s.distance, category: ExerciseCategory(rawValue: s.categoryRawValue) ?? .strength, note: s.note, sortIndex: s.sortIndex)
                nyRoutine.segments.append(nySegment)
            }
            context.insert(nyRoutine)
        }
        
        // Gjenopprett logger
        for l in payload.logs {
            let nyLog = WorkoutLog(routineName: l.routineName, date: l.date, totalDuration: l.totalDuration)
            
            for ex in l.exercises {
                let nyExercise = LoggedExercise(name: ex.name, categoryRawValue: ex.category, duration: ex.duration, reps: ex.reps, weight: ex.weight, distance: ex.distance, note: ex.note)
                nyLog.exercises.append(nyExercise)
            }
            context.insert(nyLog)
        }
        
        // Lagre endringene
        try context.save()
    }
    
    // Generer CSV for regneark (kun for historikk/logs)
    static func generateCSV(logs: [WorkoutLog]) -> URL? {
        var csvString = "Dato,Øktnavn,Øvelse,Kategori,Tid(sek),Reps,Vekt,Distanse,Notat\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        for log in logs {
            let dateString = dateFormatter.string(from: log.date)
            for ex in log.exercises {
                // Fjerner evt. komma i notater for ikke å ødelegge CSV-formatet
                let safeNote = ex.note.replacingOccurrences(of: ",", with: ";")
                let safeExerciseName = ex.name.replacingOccurrences(of: ",", with: "")
                let safeRoutineName = log.routineName.replacingOccurrences(of: ",", with: "")
                
                let row = "\(dateString),\(safeRoutineName),\(safeExerciseName),\(ex.categoryRawValue),\(ex.durationSeconds),\(ex.targetReps),\(ex.weight),\(ex.distance),\(safeNote)\n"
                csvString.append(row)
            }
        }
        
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Treningsdata_Eksport.csv")
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Feil ved generering av CSV: \(error)")
            return nil
        }
    }
}
