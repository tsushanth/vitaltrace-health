//
//  VitalReading.swift
//  VitalTrace
//
//  Base model for vital sign readings
//

import Foundation
import SwiftData

@Model
final class VitalReading {
    var id: UUID
    var timestamp: Date
    var readingType: String
    var value: Double
    var unit: String
    var note: String?
    var isValid: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        readingType: String,
        value: Double,
        unit: String,
        note: String? = nil,
        isValid: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.readingType = readingType
        self.value = value
        self.unit = unit
        self.note = note
        self.isValid = isValid
    }
}

// MARK: - Reading Type
enum ReadingType: String, CaseIterable, Codable {
    case heartRate = "heart_rate"
    case spO2 = "spo2"
    case hrv = "hrv"
    case healthScore = "health_score"

    var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .spO2: return "Blood Oxygen"
        case .hrv: return "HRV"
        case .healthScore: return "Health Score"
        }
    }

    var unit: String {
        switch self {
        case .heartRate: return "BPM"
        case .spO2: return "%"
        case .hrv: return "ms"
        case .healthScore: return "pts"
        }
    }

    var icon: String {
        switch self {
        case .heartRate: return "waveform.path.ecg"
        case .spO2: return "lungs.fill"
        case .hrv: return "waveform.path"
        case .healthScore: return "heart.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .heartRate: return "red"
        case .spO2: return "blue"
        case .hrv: return "purple"
        case .healthScore: return "green"
        }
    }
}
