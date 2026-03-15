//
//  HeartRateReading.swift
//  VitalTrace
//
//  Model for heart rate measurements
//

import Foundation
import SwiftData

@Model
final class HeartRateReading {
    var id: UUID
    var timestamp: Date
    var bpm: Double
    var confidence: Double
    var hrv: Double?
    var measurementDuration: TimeInterval
    var source: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        bpm: Double,
        confidence: Double = 1.0,
        hrv: Double? = nil,
        measurementDuration: TimeInterval = 30,
        source: String = "camera"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
        self.confidence = confidence
        self.hrv = hrv
        self.measurementDuration = measurementDuration
        self.source = source
    }

    var category: HeartRateCategory {
        switch bpm {
        case ..<60: return .low
        case 60...100: return .normal
        case 101...140: return .elevated
        default: return .high
        }
    }

    var isNormal: Bool {
        category == .normal
    }

    var formattedBPM: String {
        String(format: "%.0f", bpm)
    }
}

// MARK: - Heart Rate Category
enum HeartRateCategory: String, CaseIterable {
    case low = "Low"
    case normal = "Normal"
    case elevated = "Elevated"
    case high = "High"

    var color: String {
        switch self {
        case .low: return "blue"
        case .normal: return "green"
        case .elevated: return "orange"
        case .high: return "red"
        }
    }

    var description: String {
        switch self {
        case .low: return "Below 60 BPM - Consider consulting a doctor"
        case .normal: return "60-100 BPM - Healthy resting heart rate"
        case .elevated: return "101-140 BPM - Moderately elevated"
        case .high: return "Above 140 BPM - Seek medical attention"
        }
    }
}

// MARK: - Sample Data
extension HeartRateReading {
    static var sample: HeartRateReading {
        HeartRateReading(bpm: 72, confidence: 0.95, hrv: 45.2)
    }

    static var samples: [HeartRateReading] {
        let values: [Double] = [68, 72, 75, 71, 69, 74, 78, 73, 70, 76]
        return values.enumerated().map { index, bpm in
            HeartRateReading(
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 3600)),
                bpm: bpm,
                hrv: Double.random(in: 30...70)
            )
        }
    }
}
