import SwiftUI
import SwiftData

struct AddSegmentView: View {
    @Environment(\.modelContext) var modelContext
    
    // Vi trenger ikke lenger routine, da vi endrer rett på segmentet
    var routine: CircuitRoutine
    var segmentToEdit: CircuitExercise?
    
    var onDismiss: () -> Void
    var onRequestPicker: (String, Binding<Int>, ClosedRange<Int>, Int) -> Void
    var onTyping: () -> Void
    
    // UI-tilstander
    @State private var name = ""
    @State private var selectedCategory: ExerciseCategory = .strength
    @State private var note = ""
    @State private var selectedType: SegmentType = .duration
    @State private var duration = 45
    @State private var targetReps = 10
    
    @State private var showDeleteConfirmation = false
    
    // Fokus-kontroll
    @FocusState private var isNameFocused: Bool
    @FocusState private var isNoteFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. NAVN
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Øvelsesnavn")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("F.eks. Knebøy", text: $name)
                            .font(.title3)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onChange(of: name) { _, _ in updateSegment() } // FIKSET
                            .onChange(of: isNameFocused) { _, focused in    // FIKSET
                                if focused { onTyping() }
                            }
                    }
                    
                    // 2. KATEGORI
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategori")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(ExerciseCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    withAnimation(.snappy) {
                                        selectedCategory = category
                                        updateSegment()
                                    }
                                }) {
                                    Text(category.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedCategory == category
                                            ? AppTheme.standard.color(for: category)
                                            : Color(.systemGray6)
                                        )
                                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    
                    // 3. TYPE
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Type", selection: $selectedType) {
                            ForEach(SegmentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedType) { _, _ in updateSegment() } // FIKSET
                    }
                    
                    // 4. VERDI
                    VStack(alignment: .leading, spacing: 8) {
                        Text(valueTitle())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            if selectedType == .duration || selectedType == .pause {
                                onRequestPicker(valueTitle(), $duration, 5...600, 5)
                            } else {
                                onRequestPicker(valueTitle(), $targetReps, 1...100, 1)
                            }
                        }) {
                            HStack {
                                Text(valueString())
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .onChange(of: duration) { _, _ in updateSegment() }   // FIKSET
                    .onChange(of: targetReps) { _, _ in updateSegment() } // FIKSET
                    
                    // 5. NOTATER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notater (valgfritt)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Teknikk, vekt, etc...", text: $note)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .focused($isNoteFocused)
                            .submitLabel(.done)
                            .onChange(of: note) { _, _ in updateSegment() } // FIKSET
                            .onChange(of: isNoteFocused) { _, focused in    // FIKSET
                                if focused { onTyping() }
                            }
                    }
                    
                    Spacer(minLength: 20)
                    
                    // SLETT KNAPP
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Slett del")
                        }
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            if let segment = segmentToEdit {
                name = segment.name
                selectedCategory = segment.category
                note = segment.note
                selectedType = segment.type
                duration = segment.durationSeconds
                targetReps = segment.targetReps
            }
        }
        .alert("Slett?", isPresented: $showDeleteConfirmation) {
            Button("Avbryt", role: .cancel) { }
            Button("Slett", role: .destructive) { deleteSegment() }
        } message: {
            Text("Er du sikker på at du vil fjerne denne delen?")
        }
    }
    
    // --- LOGIKK ---
    
    func updateSegment() {
        guard let segment = segmentToEdit else { return }
        
        segment.name = name
        segment.category = selectedCategory
        segment.note = note
        segment.type = selectedType
        segment.durationSeconds = duration
        segment.targetReps = targetReps
    }
    
    func deleteSegment() {
        guard let segment = segmentToEdit else { return }
        if let index = routine.segments.firstIndex(of: segment) {
            routine.segments.remove(at: index)
        }
        modelContext.delete(segment)
        onDismiss()
    }
    
    // --- UI HJELPERE ---
    func valueTitle() -> String {
        switch selectedType {
        case .duration: return "Varighet"
        case .reps: return "Antall"
        case .stopwatch: return "Mål (reps)"
        case .pause: return "Pause varighet"
        }
    }
    
    func valueString() -> String {
        switch selectedType {
        case .duration: return "\(duration) sek"
        case .reps: return "\(targetReps) reps"
        case .stopwatch: return "\(targetReps) reps"
        case .pause: return "\(duration) sek"
        }
    }
}
