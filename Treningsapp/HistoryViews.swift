//
//  HistoryViews.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 15/02/2026.
//
import SwiftUI
import SwiftData

// Enum for å styre visningsmodus
enum HistoryViewMode: String, CaseIterable {
    case list = "Liste"
    case calendar = "Kalender"
}

// MARK: - History List View (Den gamle visningen)
struct HistoryListView: View {
    let logs: [WorkoutLog]
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(logs) { log in
                HistoryRow(log: log)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - History Calendar View (Den nye visningen)
struct HistoryCalendarView: View {
    let logs: [WorkoutLog]
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    // Hjelper for å finne logger på en spesifikk dag
    func logsForDate(_ date: Date) -> [WorkoutLog] {
        logs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    var body: some View {
        // Endret spacing fra 20 til 10 for å spare plass
        VStack(spacing: 10) {
            
            // 1. Måned Navigasjon
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthYearString(from: currentMonth))
                    .font(.headline)
                    .bold()
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            .padding(.top, 5) // Redusert padding
            
            // 2. Ukedager
            HStack {
                ForEach(["Man", "Tir", "Ons", "Tor", "Fre", "Lør", "Søn"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 3. Kalender Grid
            // Redusert spacing fra 15 til 6 for å gjøre kalenderen lavere
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        let dayLogs = logsForDate(date)
                        let hasWorkout = !dayLogs.isEmpty
                        let isSelected = selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!)
                        let isToday = calendar.isDateInToday(date)
                        
                        VStack(spacing: 2) { // Redusert intern spacing
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 14))
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
                            
                            // Grønn prikk hvis trening finnes
                            if hasWorkout {
                                Circle()
                                    .fill(isSelected ? .white : Color.green)
                                    .frame(width: 5, height: 5)
                            } else {
                                Circle().fill(Color.clear).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 32) // Redusert høyde fra 40 til 32
                        .background(
                            ZStack {
                                if isSelected {
                                    Circle().fill(Color.blue)
                                } else if isToday && !hasWorkout {
                                    Circle().stroke(Color.blue, lineWidth: 1)
                                }
                            }
                        )
                        .onTapGesture {
                            withAnimation(.snappy) {
                                if isSelected {
                                    selectedDate = nil // Deselect
                                } else {
                                    selectedDate = date
                                }
                            }
                        }
                    } else {
                        // Tom plass for dager før månedstart
                        Text("").frame(height: 32)
                    }
                }
            }
            .padding(.horizontal)
            
            // 4. Detaljer for valgt dag (eller info om ingen valgt)
            VStack {
                if let selected = selectedDate {
                    let selectedLogs = logsForDate(selected)
                    
                    HStack {
                        Text(selected.formatted(date: .complete, time: .omitted))
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                    
                    if selectedLogs.isEmpty {
                        Text("Ingen trening registrert denne dagen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(selectedLogs) { log in
                            HistoryRow(log: log)
                                .padding(.vertical, 4)
                        }
                    }
                } else {
                    // Vis statistikk for måneden hvis ingen dag er valgt
                    let monthLogs = logs.filter { calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }
                    VStack(spacing: 2) {
                        Text("\(monthLogs.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded)) // Litt mindre font
                            .foregroundStyle(.blue)
                        Text("Økter i \(monthName(from: currentMonth))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)
                }
            }
            
            Spacer()
        }
    }
    
    // --- KALENDER LOGIKK ---
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            selectedDate = nil // Nullstill valg ved bytte av måned
        }
    }
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    func monthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
    
    func daysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Juster slik at mandag = 1 (SwiftUI calendar starter ofte med søndag=1)
        // I Norge er mandag første dag. Søndag(1) blir 7, Mandag(2) blir 1.
        let offset = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
}
