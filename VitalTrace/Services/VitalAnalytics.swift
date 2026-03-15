//
//  VitalAnalytics.swift
//  VitalTrace
//
//  Analytics, attribution, and tracking services
//

import Foundation
import AppTrackingTransparency
import AdServices

// MARK: - Analytics Event
enum AnalyticsEvent {
    case appOpen
    case measurementStarted(type: String)
    case measurementCompleted(type: String, value: Double)
    case paywallViewed
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String)
    case purchaseFailed(productID: String, error: String)
    case restorePurchases
    case onboardingCompleted
    case healthKitConnected
    case exportDataTapped
    case signUp(method: String)
    case viewHealth(tab: String)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .measurementStarted: return "measurement_started"
        case .measurementCompleted: return "measurement_completed"
        case .paywallViewed: return "paywall_viewed"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .restorePurchases: return "restore_purchases"
        case .onboardingCompleted: return "onboarding_completed"
        case .healthKitConnected: return "healthkit_connected"
        case .exportDataTapped: return "export_data_tapped"
        case .signUp: return "sign_up"
        case .viewHealth: return "view_health"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .appOpen: return [:]
        case .measurementStarted(let type): return ["type": type]
        case .measurementCompleted(let type, let value): return ["type": type, "value": value]
        case .paywallViewed: return [:]
        case .purchaseStarted(let productID): return ["product_id": productID]
        case .purchaseCompleted(let productID): return ["product_id": productID]
        case .purchaseFailed(let productID, let error): return ["product_id": productID, "error": error]
        case .restorePurchases: return [:]
        case .onboardingCompleted: return [:]
        case .healthKitConnected: return [:]
        case .exportDataTapped: return [:]
        case .signUp(let method): return ["method": method]
        case .viewHealth(let tab): return ["tab": tab]
        }
    }
}

// MARK: - Analytics Service
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    private var isInitialized = false

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        // Firebase Analytics initialization would go here
        // FirebaseApp.configure()
        print("[Analytics] Initialized")
    }

    func track(_ event: AnalyticsEvent) {
        guard isInitialized else { return }
        // Firebase Analytics tracking would go here
        // Analytics.logEvent(event.name, parameters: event.parameters)
        print("[Analytics] \(event.name): \(event.parameters)")
    }

    func setUserProperty(_ value: String?, forName name: String) {
        // Analytics.setUserProperty(value, forName: name)
        print("[Analytics] Set property \(name): \(value ?? "nil")")
    }

    func setUserId(_ userId: String?) {
        // Analytics.setUserID(userId)
        print("[Analytics] Set user ID: \(userId ?? "nil")")
    }
}

// MARK: - ATT Service
@MainActor
final class ATTService {
    static let shared = ATTService()
    private init() {}

    private let hasRequestedKey = "com.appfactory.vitaltrace.att_requested"

    var hasRequestedPermission: Bool {
        UserDefaults.standard.bool(forKey: hasRequestedKey)
    }

    var trackingStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    func requestIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        guard !hasRequestedPermission else {
            return ATTrackingManager.trackingAuthorizationStatus
        }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        UserDefaults.standard.set(true, forKey: hasRequestedKey)

        print("[ATT] Tracking authorization status: \(status.rawValue)")
        return status
    }
}

// MARK: - Attribution Manager
@MainActor
final class AttributionManager {
    static let shared = AttributionManager()
    private init() {}

    private let hasRequestedKey = "com.appfactory.vitaltrace.attribution_requested"

    func requestAttributionIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: hasRequestedKey) else { return }
        UserDefaults.standard.set(true, forKey: hasRequestedKey)

        do {
            let token = try AAAttribution.attributionToken()
            print("[Attribution] Token: \(token.prefix(20))...")
            // Send token to your attribution backend
        } catch {
            print("[Attribution] Failed to get token: \(error.localizedDescription)")
        }
    }
}

// MARK: - Health Score Calculator
final class HealthScoreCalculator {
    static func calculate(
        heartRateReadings: [HeartRateReading],
        oxygenReadings: [OxygenReading]
    ) -> HealthScore {
        let hrScore = calculateHeartRateScore(heartRateReadings)
        let spo2Score = calculateSpO2Score(oxygenReadings)
        let hrvScore = calculateHRVScore(heartRateReadings)
        let consistencyScore = calculateConsistencyScore(
            hrCount: heartRateReadings.count,
            spo2Count: oxygenReadings.count
        )

        let totalScore = (hrScore * 0.3 + spo2Score * 0.35 + hrvScore * 0.2 + consistencyScore * 0.15)

        return HealthScore(
            score: totalScore,
            heartRateScore: hrScore,
            spO2Score: spo2Score,
            hrvScore: hrvScore,
            consistencyScore: consistencyScore
        )
    }

    private static func calculateHeartRateScore(_ readings: [HeartRateReading]) -> Double {
        guard !readings.isEmpty else { return 50 }

        let avgBPM = readings.map { $0.bpm }.reduce(0, +) / Double(readings.count)

        switch avgBPM {
        case 60...80: return 100
        case 50..<60, 80..<90: return 85
        case 40..<50, 90..<100: return 70
        case 30..<40, 100..<120: return 50
        default: return 25
        }
    }

    private static func calculateSpO2Score(_ readings: [OxygenReading]) -> Double {
        guard !readings.isEmpty else { return 50 }

        let avgSpO2 = readings.map { $0.spO2 }.reduce(0, +) / Double(readings.count)

        switch avgSpO2 {
        case 98...100: return 100
        case 96..<98: return 90
        case 95..<96: return 75
        case 93..<95: return 55
        case 90..<93: return 35
        default: return 10
        }
    }

    private static func calculateHRVScore(_ readings: [HeartRateReading]) -> Double {
        let validHRV = readings.compactMap { $0.hrv }
        guard !validHRV.isEmpty else { return 50 }

        let avgHRV = validHRV.reduce(0, +) / Double(validHRV.count)

        switch avgHRV {
        case 50...: return 100
        case 40..<50: return 85
        case 30..<40: return 70
        case 20..<30: return 55
        default: return 35
        }
    }

    private static func calculateConsistencyScore(hrCount: Int, spo2Count: Int) -> Double {
        let totalReadings = hrCount + spo2Count
        switch totalReadings {
        case 10...: return 100
        case 6..<10: return 80
        case 3..<6: return 60
        case 1..<3: return 40
        default: return 20
        }
    }
}

// MARK: - Data Exporter
final class DataExporter {
    static func exportToCSV(
        heartRateReadings: [HeartRateReading],
        oxygenReadings: [OxygenReading]
    ) -> String {
        var csv = "Date,Time,Type,Value,Unit\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        for reading in heartRateReadings.sorted(by: { $0.timestamp < $1.timestamp }) {
            let date = formatter.string(from: reading.timestamp)
            let time = timeFormatter.string(from: reading.timestamp)
            csv += "\(date),\(time),Heart Rate,\(String(format: "%.0f", reading.bpm)),BPM\n"

            if let hrv = reading.hrv {
                csv += "\(date),\(time),HRV,\(String(format: "%.1f", hrv)),ms\n"
            }
        }

        for reading in oxygenReadings.sorted(by: { $0.timestamp < $1.timestamp }) {
            let date = formatter.string(from: reading.timestamp)
            let time = timeFormatter.string(from: reading.timestamp)
            csv += "\(date),\(time),Blood Oxygen,\(String(format: "%.1f", reading.spO2)),%\n"
        }

        return csv
    }

    static func exportToJSON(
        heartRateReadings: [HeartRateReading],
        oxygenReadings: [OxygenReading]
    ) -> Data? {
        let hrData = heartRateReadings.map { reading -> [String: Any] in
            var dict: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: reading.timestamp),
                "bpm": reading.bpm,
                "confidence": reading.confidence
            ]
            if let hrv = reading.hrv { dict["hrv"] = hrv }
            return dict
        }

        let spo2Data = oxygenReadings.map { reading -> [String: Any] in
            [
                "timestamp": ISO8601DateFormatter().string(from: reading.timestamp),
                "spo2": reading.spO2,
                "confidence": reading.confidence
            ]
        }

        let exportData: [String: Any] = [
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "heart_rate_readings": hrData,
            "oxygen_readings": spo2Data
        ]

        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}
