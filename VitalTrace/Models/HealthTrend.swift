//
//  HealthTrend.swift
//  VitalTrace
//
//  Model for health trend data aggregations
//

import Foundation
import SwiftData

@Model
final class HealthTrend {
    var id: UUID
    var date: Date
    var averageHeartRate: Double?
    var minHeartRate: Double?
    var maxHeartRate: Double?
    var averageSpO2: Double?
    var minSpO2: Double?
    var averageHRV: Double?
    var readingCount: Int
    var trendPeriod: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        averageHeartRate: Double? = nil,
        minHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        averageSpO2: Double? = nil,
        minSpO2: Double? = nil,
        averageHRV: Double? = nil,
        readingCount: Int = 0,
        trendPeriod: String = TrendPeriod.day.rawValue
    ) {
        self.id = id
        self.date = date
        self.averageHeartRate = averageHeartRate
        self.minHeartRate = minHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageSpO2 = averageSpO2
        self.minSpO2 = minSpO2
        self.averageHRV = averageHRV
        self.readingCount = readingCount
        self.trendPeriod = trendPeriod
    }
}

// MARK: - Trend Period
enum TrendPeriod: String, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case threeMonths = "three_months"

    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        }
    }

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

extension HealthTrend {
    static var samples: [HealthTrend] {
        (0..<7).map { dayOffset in
            HealthTrend(
                date: Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date(),
                averageHeartRate: Double.random(in: 65...85),
                minHeartRate: Double.random(in: 55...65),
                maxHeartRate: Double.random(in: 85...110),
                averageSpO2: Double.random(in: 96...99),
                minSpO2: Double.random(in: 94...96),
                averageHRV: Double.random(in: 30...60),
                readingCount: Int.random(in: 2...8),
                trendPeriod: TrendPeriod.day.rawValue
            )
        }
    }
}
