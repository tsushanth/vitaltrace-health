//
//  HealthScore.swift
//  VitalTrace
//
//  Model for daily health score calculations
//

import Foundation
import SwiftData

@Model
final class HealthScore {
    var id: UUID
    var date: Date
    var score: Double
    var heartRateScore: Double
    var spO2Score: Double
    var hrvScore: Double
    var consistencyScore: Double
    var breakdown: String // JSON encoded breakdown

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        score: Double,
        heartRateScore: Double = 0,
        spO2Score: Double = 0,
        hrvScore: Double = 0,
        consistencyScore: Double = 0,
        breakdown: String = "{}"
    ) {
        self.id = id
        self.date = date
        self.score = score
        self.heartRateScore = heartRateScore
        self.spO2Score = spO2Score
        self.hrvScore = hrvScore
        self.consistencyScore = consistencyScore
        self.breakdown = breakdown
    }

    var category: HealthScoreCategory {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .poor
        }
    }

    var formattedScore: String {
        String(format: "%.0f", score)
    }
}

// MARK: - Health Score Category
enum HealthScoreCategory: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }

    var emoji: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .fair: return "exclamationmark.circle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }

    var message: String {
        switch self {
        case .excellent: return "Your vitals are excellent today!"
        case .good: return "Your vitals look good today."
        case .fair: return "Some vitals need attention."
        case .poor: return "Consider consulting a healthcare provider."
        }
    }
}

// MARK: - Score Component
struct ScoreComponent: Identifiable {
    let id = UUID()
    let name: String
    let score: Double
    let maxScore: Double
    let icon: String

    var percentage: Double {
        guard maxScore > 0 else { return 0 }
        return (score / maxScore) * 100
    }
}

extension HealthScore {
    static var sample: HealthScore {
        HealthScore(
            score: 82,
            heartRateScore: 85,
            spO2Score: 90,
            hrvScore: 75,
            consistencyScore: 80
        )
    }

    var components: [ScoreComponent] {
        [
            ScoreComponent(name: "Heart Rate", score: heartRateScore, maxScore: 100, icon: "waveform.path.ecg"),
            ScoreComponent(name: "Blood Oxygen", score: spO2Score, maxScore: 100, icon: "lungs.fill"),
            ScoreComponent(name: "HRV", score: hrvScore, maxScore: 100, icon: "waveform.path"),
            ScoreComponent(name: "Consistency", score: consistencyScore, maxScore: 100, icon: "calendar.badge.checkmark"),
        ]
    }
}
