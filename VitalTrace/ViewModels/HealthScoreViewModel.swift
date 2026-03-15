//
//  HealthScoreViewModel.swift
//  VitalTrace
//
//  ViewModel for daily health score calculation and display
//

import Foundation
import SwiftData

@MainActor
@Observable
final class HealthScoreViewModel {
    var todayScore: HealthScore?
    var scoreHistory: [HealthScore] = []
    var isCalculating: Bool = false
    var errorMessage: String?

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadTodayScore()
        loadScoreHistory()
    }

    // MARK: - Load
    func loadTodayScore() {
        guard let context = modelContext else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<HealthScore>(
            predicate: #Predicate { $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        todayScore = try? context.fetch(descriptor).first
    }

    func loadScoreHistory() {
        guard let context = modelContext else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<HealthScore>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        scoreHistory = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Calculate
    func recalculateScore() async {
        guard let context = modelContext else { return }
        isCalculating = true

        let startOfDay = Calendar.current.startOfDay(for: Date())

        let hrDescriptor = FetchDescriptor<HeartRateReading>(
            predicate: #Predicate { $0.timestamp >= startOfDay }
        )
        let spo2Descriptor = FetchDescriptor<OxygenReading>(
            predicate: #Predicate { $0.timestamp >= startOfDay }
        )

        let hrReadings = (try? context.fetch(hrDescriptor)) ?? []
        let spo2Readings = (try? context.fetch(spo2Descriptor)) ?? []

        let newScore = HealthScoreCalculator.calculate(
            heartRateReadings: hrReadings,
            oxygenReadings: spo2Readings
        )

        // Remove existing today's score
        if let existing = todayScore {
            context.delete(existing)
        }

        context.insert(newScore)
        try? context.save()

        todayScore = newScore
        loadScoreHistory()
        isCalculating = false
    }

    // MARK: - Computed
    var scoreDisplay: String {
        guard let score = todayScore else { return "--" }
        return score.formattedScore
    }

    var scoreCategory: HealthScoreCategory {
        todayScore?.category ?? .fair
    }

    var scoreMessage: String {
        scoreCategory.message
    }

    var scoreHistoryChartData: [ChartDataPoint] {
        scoreHistory.map { score in
            ChartDataPoint(
                date: score.date,
                value: score.score,
                label: score.formattedScore
            )
        }.sorted { $0.date < $1.date }
    }

    var weeklyAverage: Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = scoreHistory.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map { $0.score }.reduce(0, +) / Double(recent.count)
    }

    var trend: ScoreTrend {
        guard scoreHistory.count >= 2 else { return .stable }
        let recent = Array(scoreHistory.prefix(3))
        let older = Array(scoreHistory.dropFirst(3).prefix(3))

        guard !older.isEmpty else { return .stable }

        let recentAvg = recent.map { $0.score }.reduce(0, +) / Double(recent.count)
        let olderAvg = older.map { $0.score }.reduce(0, +) / Double(older.count)

        if recentAvg > olderAvg + 5 { return .improving }
        if recentAvg < olderAvg - 5 { return .declining }
        return .stable
    }
}

// MARK: - Score Trend
enum ScoreTrend {
    case improving
    case declining
    case stable

    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .improving: return "green"
        case .declining: return "red"
        case .stable: return "blue"
        }
    }

    var description: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
}
