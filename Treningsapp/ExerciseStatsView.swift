import SwiftUI
import SwiftData
import Charts

struct ExerciseStatsView: View {
    let exerciseName: String
    let category: ExerciseCategory
    
    @Query(sort: \WorkoutLog.date, order: .forward) private var allLogs: [WorkoutLog]
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedModes: Set<StatMode> = []
    @State private var availableModes: [StatMode] = []
    @State private var chartOpacity: Double = 0.0
    
    // --- FASTE FARGER ---
    func color(for mode: StatMode) -> Color {
        switch mode {
        case .weight: return .blue
        case .distance: return .cyan
        case .reps: return .green
        case .time: return .orange
        case .efficiency: return .purple
        }
    }
    
    struct DataPoint: Identifiable {
        var id: String { "\(date.timeIntervalSince1970)-\(mode.rawValue)" }
        let date: Date
        let value: Double
        let originalValue: Double
        let unit: String
        let mode: StatMode
        let seriesName: String
    }
    
    enum StatMode: String, CaseIterable, Identifiable {
        case weight = "Kg"
        case distance = "Distanse"
        case reps = "Antall"
        case time = "Tid"
        case efficiency = "Intensitet"
        var id: String { self.rawValue }
        var isSecondary: Bool { self == .efficiency }
    }
    
    // --- BEREGNINGER ---
    
    var scalingFactor: Double {
        // Vi splitter opp beregningen for å hjelpe kompilatoren
        let leftModes = selectedModes.filter { !$0.isSecondary }
        let rightModes = selectedModes.filter { $0.isSecondary }
        
        // Finn maks for venstre akse
        var maxLeft: Double = 0
        for log in allLogs {
            guard let match = log.exercises.first(where: { $0.name == exerciseName }) else { continue }
            if leftModes.contains(.weight) { maxLeft = max(maxLeft, match.weight) }
            if leftModes.contains(.distance) { maxLeft = max(maxLeft, match.distance) }
            if leftModes.contains(.reps) { maxLeft = max(maxLeft, Double(match.targetReps)) }
            if leftModes.contains(.time) { maxLeft = max(maxLeft, Double(match.durationSeconds) / 60.0) }
        }
        
        // Finn maks for høyre akse
        var maxRight: Double = 0
        if rightModes.contains(.efficiency) {
            for log in allLogs {
                guard let match = log.exercises.first(where: { $0.name == exerciseName }) else { continue }
                if match.durationSeconds > 0 {
                    let rpm = Double(match.targetReps) / (Double(match.durationSeconds) / 60.0)
                    maxRight = max(maxRight, rpm)
                }
            }
        }
        
        if maxLeft > 0 && maxRight > 0 { return maxLeft / maxRight }
        return 1.0
    }
    
    var chartData: [DataPoint] {
        var points: [DataPoint] = []
        let factor = scalingFactor
        
        for log in allLogs {
            guard let match = log.exercises.first(where: { $0.name == exerciseName }) else { continue }
            
            // Venstre
            if selectedModes.contains(.weight) && match.weight > 0 {
                points.append(DataPoint(date: log.date, value: match.weight, originalValue: match.weight, unit: "kg", mode: .weight, seriesName: StatMode.weight.rawValue))
            }
            if selectedModes.contains(.distance) && match.distance > 0 {
                points.append(DataPoint(date: log.date, value: match.distance, originalValue: match.distance, unit: "m", mode: .distance, seriesName: StatMode.distance.rawValue))
            }
            if selectedModes.contains(.reps) && match.targetReps > 0 {
                points.append(DataPoint(date: log.date, value: Double(match.targetReps), originalValue: Double(match.targetReps), unit: "reps", mode: .reps, seriesName: StatMode.reps.rawValue))
            }
            if selectedModes.contains(.time) && match.durationSeconds > 0 {
                let mins = Double(match.durationSeconds) / 60.0
                points.append(DataPoint(date: log.date, value: mins, originalValue: mins, unit: "min", mode: .time, seriesName: StatMode.time.rawValue))
            }
            // Høyre
            if selectedModes.contains(.efficiency) && match.targetReps > 0 && match.durationSeconds > 0 {
                let rpm = Double(match.targetReps) / (Double(match.durationSeconds) / 60.0)
                points.append(DataPoint(date: log.date, value: rpm * factor, originalValue: rpm, unit: "rpm", mode: .efficiency, seriesName: StatMode.efficiency.rawValue))
            }
        }
        return points
    }
    
    struct ListRowData: Identifiable {
        let id = UUID()
        let date: Date
        let details: [(text: String, color: Color)]
    }
    
    var listData: [ListRowData] {
        var rows: [ListRowData] = []
        for log in allLogs.reversed() {
            if let match = log.exercises.first(where: { $0.name == exerciseName }) {
                var details: [(String, Color)] = []
                
                if selectedModes.contains(.weight) && match.weight > 0 { details.append(("\(Int(match.weight)) kg", color(for: .weight))) }
                if selectedModes.contains(.reps) && match.targetReps > 0 { details.append(("\(match.targetReps) reps", color(for: .reps))) }
                if selectedModes.contains(.distance) && match.distance > 0 { details.append(("\(Int(match.distance)) m", color(for: .distance))) }
                if selectedModes.contains(.time) && match.durationSeconds > 0 { details.append((formatDuration(match.durationSeconds), color(for: .time))) }
                if selectedModes.contains(.efficiency) && match.targetReps > 0 && match.durationSeconds > 0 {
                    let rpm = Double(match.targetReps) / (Double(match.durationSeconds) / 60.0)
                    details.append((String(format: "%.1f rpm", rpm), color(for: .efficiency)))
                }
                
                if !details.isEmpty {
                    rows.append(ListRowData(date: log.date, details: details))
                }
            }
        }
        return rows
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // --- GRAF ---
                VStack(alignment: .leading, spacing: 10) {
                    if !chartData.isEmpty {
                        Chart {
                            ForEach(chartData) { point in
                                LineMark(
                                    x: .value("Dato", point.date),
                                    y: .value("Verdi", point.value)
                                )
                                .interpolationMethod(.catmullRom)
                                .symbol(by: .value("Type", point.seriesName))
                                .foregroundStyle(color(for: point.mode))
                            }
                        }
                        .chartYAxis {
                            // Vi bruker egne funksjoner for aksene for å unngå "complex expression"-feil
                            leftAxis()
                            rightAxis()
                        }
                        // .chartAnimation(.disabled) // Kommentert ut i tilfelle eldre iOS versjoner, opasitet styrer dette uansett.
                        .frame(height: 250)
                        .padding()
                        .opacity(chartOpacity)
                    } else {
                        ContentUnavailableView(
                            "Ingen data valgt",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Velg parametere under for å se graf.")
                        )
                        .frame(height: 250)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // --- KNAPPER ---
                if !availableModes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableModes) { mode in
                                ToggleButton(
                                    title: mode.rawValue,
                                    isSelected: selectedModes.contains(mode),
                                    color: color(for: mode)
                                ) {
                                    handleToggle(mode)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 5)
                }
                
                // --- LISTE ---
                List {
                    Section("Historikk") {
                        ForEach(listData) { row in
                            HStack(alignment: .top) {
                                Text(row.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    ForEach(row.details, id: \.text) { detail in
                                        Text(detail.text).bold().foregroundStyle(detail.color)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Lukk") { dismiss() } }
            }
            .onAppear {
                calculateAvailableModes()
                withAnimation(.easeIn(duration: 0.6)) { chartOpacity = 1.0 }
            }
        }
    }
    
    // --- HJELPEFUNKSJONER FOR AKSENE ---
    
    @AxisContentBuilder
    func leftAxis() -> some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine()
            if let d = value.as(Double.self) {
                AxisValueLabel("\(Int(d))")
            }
        }
    }
    
    @AxisContentBuilder
    func rightAxis() -> some AxisContent {
        if selectedModes.contains(.efficiency) && scalingFactor != 1.0 {
            AxisMarks(position: .trailing) { value in
                if let d = value.as(Double.self) {
                    let original = d / scalingFactor
                    AxisValueLabel(String(format: "%.1f", original))
                }
            }
        }
    }
    
    // --- LOGIKK ---
    
    func handleToggle(_ mode: StatMode) {
        withAnimation(.easeOut(duration: 0.15)) { chartOpacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if selectedModes.contains(mode) {
                if selectedModes.count > 1 { selectedModes.remove(mode) }
            } else {
                selectedModes.insert(mode)
            }
            withAnimation(.easeIn(duration: 0.3)) { chartOpacity = 1.0 }
        }
    }
    
    func calculateAvailableModes() {
        let exercises = allLogs.flatMap { $0.exercises }.filter { $0.name == exerciseName }
        var modes: [StatMode] = []
        if exercises.isEmpty { availableModes = [.reps]; selectedModes = [.reps]; return }
        
        if exercises.contains(where: { $0.weight > 0 }) { modes.append(.weight) }
        if exercises.contains(where: { $0.targetReps > 0 }) { modes.append(.reps) }
        if exercises.contains(where: { $0.distance > 0 }) { modes.append(.distance) }
        if exercises.contains(where: { $0.durationSeconds > 0 }) { modes.append(.time) }
        if exercises.contains(where: { $0.targetReps > 0 && $0.durationSeconds > 0 }) { modes.append(.efficiency) }
        
        self.availableModes = modes
        if selectedModes.isEmpty {
            if category == .strength && modes.contains(.weight) { selectedModes = [.weight] }
            else if category == .cardio && modes.contains(.distance) { selectedModes = [.distance] }
            else if modes.contains(.efficiency) { selectedModes = [.efficiency] }
            else if let first = modes.first { selectedModes = [first] }
        }
    }
    
    func formatDuration(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let hundredths = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)
        if hundredths > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark").font(.caption2.bold()) }
                Text(title).fontWeight(.medium)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1.5))
        }
    }
}
