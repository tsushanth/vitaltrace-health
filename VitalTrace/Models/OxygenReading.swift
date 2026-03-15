//
//  OxygenReading.swift
//  VitalTrace
//
//  Model for blood oxygen (SpO2) measurements
//

import Foundation
import SwiftData

@Model
final class OxygenReading {
    var id: UUID
    var timestamp: Date
    var spO2: Double
    var confidence: Double
    var measurementDuration: TimeInterval
    var source: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        spO2: Double,
        confidence: Double = 1.0,
        measurementDuration: TimeInterval = 30,
        source: String = "camera"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.spO2 = spO2
        self.confidence = confidence
        self.measurementDuration = measurementDuration
        self.source = source
    }

    var category: OxygenCategory {
        switch spO2 {
        case 95...100: return .normal
        case 90..<95: return .low
        case 85..<90: return .veryLow
        default: return .critical
        }
    }

    var isNormal: Bool {
        category == .normal
    }

    var formattedSpO2: String {
        String(format: "%.1f%%", spO2)
    }
}

// MARK: - Oxygen Category
enum OxygenCategory: String, CaseIterable {
    case normal = "Normal"
    case low = "Low"
    case veryLow = "Very Low"
    case critical = "Critical"

    var color: String {
        switch self {
        case .normal: return "green"
        case .low: return "yellow"
        case .veryLow: return "orange"
        case .critical: return "red"
        }
    }

    var description: String {
        switch self {
        case .normal: return "95-100% - Normal oxygen saturation"
        case .low: return "90-94% - Mildly low, monitor closely"
        case .veryLow: return "85-89% - Significantly low, seek care"
        case .critical: return "Below 85% - Seek emergency care"
        }
    }

    var advice: String {
        switch self {
        case .normal: return "Your blood oxygen level is within the healthy range."
        case .low: return "Your oxygen level is slightly low. Rest and monitor your breathing."
        case .veryLow: return "Your oxygen level is concerningly low. Consider seeking medical advice."
        case .critical: return "Your oxygen level is critically low. Please seek immediate medical attention."
        }
    }
}

// MARK: - Sample Data
extension OxygenReading {
    static var sample: OxygenReading {
        OxygenReading(spO2: 98.2, confidence: 0.95)
    }

    static var samples: [OxygenReading] {
        let values: [Double] = [98.0, 97.5, 98.5, 99.0, 97.8, 98.2, 98.8, 97.2, 98.4, 99.1]
        return values.enumerated().map { index, spo2 in
            OxygenReading(
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 3600)),
                spO2: spo2
            )
        }
    }
}
