//
//  Settingsview.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 14/02/2026.
//
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Binding var maxCount: Int // Denne binder vi til ContentView slik at hjem-skjermen oppdateres
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Seksjon 1: Hjem-skjerm innstillinger (Det du hadde fra før)
                Section(header: Text("Hjem-skjerm")) {
                    Stepper(value: $maxCount, in: 4...7) {
                        HStack {
                            Text("Antall snarveier")
                            Spacer()
                            Text("\(maxCount)")
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Velg mellom 4 og 7 snarveier.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Seksjon 2: Innhold (Ny funksjonalitet)
                Section(header: Text("Innhold")) {
                    NavigationLink(destination: ExerciseLibraryView()) {
                        Label("Mine Øvelser", systemImage: "dumbbell.fill")
                    }
                }
                
                // Seksjon 3: Info
                Section(header: Text("Om appen")) {
                    HStack {
                        Label("Versjon", systemImage: "info.circle")
                        Spacer()
                        Text("1.0 (Test)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Innstillinger")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
        }
    }
}

// --- VISNING FOR ØVELSESBIBLIOTEK ---

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) var modelContext
    @Query var routines: [CircuitRoutine]
    
    @State private var exerciseToEdit: ExerciseEditModel?
    @State private var showingEditSheet = false
    
    // Henter ut unike øvelser fra alle rutiner
    var uniqueExercises: [(name: String, category: ExerciseCategory, count: Int)] {
        var exercises: [String: (ExerciseCategory, Int)] = [:]
        
        for routine in routines {
            for segment in routine.segments {
                let currentCount = exercises[segment.name]?.1 ?? 0
                exercises[segment.name] = (segment.category, currentCount + 1)
            }
        }
        
        return exercises.map { key, value in
            (name: key, category: value.0, count: value.1)
        }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        List {
            if uniqueExercises.isEmpty {
                ContentUnavailableView(
                    "Ingen øvelser",
                    systemImage: "dumbbell",
                    description: Text("Øvelser du legger til i økter vil dukke opp her automatisk.")
                )
            } else {
                ForEach(uniqueExercises, id: \.name) { exercise in
                    Button(action: {
                        exerciseToEdit = ExerciseEditModel(originalName: exercise.name, newName: exercise.name, category: exercise.category)
                        showingEditSheet = true
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.standard.color(for: exercise.category).opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: iconForCategory(exercise.category))
                                    .foregroundStyle(AppTheme.standard.color(for: exercise.category))
                            }
                            
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text("\(exercise.count) forekomster")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Mine Øvelser")
        .sheet(item: $exerciseToEdit) { editModel in
            EditExerciseSheet(model: editModel) { oldName, newName, newCategory in
                batchUpdateExercise(oldName: oldName, newName: newName, newCategory: newCategory)
            }
        }
    }
    
    func batchUpdateExercise(oldName: String, newName: String, newCategory: ExerciseCategory) {
        for routine in routines {
            for segment in routine.segments where segment.name == oldName {
                segment.name = newName
                segment.category = newCategory
            }
        }
        try? modelContext.save()
    }
    
    func iconForCategory(_ category: ExerciseCategory) -> String {
        switch category {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .combined: return "figure.mind.and.body"
        case .other: return "star.fill"
        }
    }
}

// --- HJELPERE FOR REDIGERING ---

struct ExerciseEditModel: Identifiable {
    let id = UUID()
    let originalName: String
    var newName: String
    var category: ExerciseCategory
}

struct EditExerciseSheet: View {
    @Environment(\.dismiss) var dismiss
    @State var model: ExerciseEditModel
    var onSave: (String, String, ExerciseCategory) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rediger øvelse")) {
                    TextField("Navn", text: $model.newName)
                    
                    Picker("Kategori", selection: $model.category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
                
                Section {
                    Text("Dette vil oppdatere navnet på denne øvelsen i alle dine lagrede økter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Endre øvelse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lagre") {
                        onSave(model.originalName, model.newName, model.category)
                        dismiss()
                    }
                    .disabled(model.newName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
