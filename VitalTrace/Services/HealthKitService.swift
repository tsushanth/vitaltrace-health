//
//  HealthKitService.swift
//  VitalTrace
//
//  HealthKit integration for reading and writing health data
//

import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitService {
    private let healthStore = HKHealthStore()

    var isAuthorized: Bool = false
    var authorizationError: String?

    // MARK: - Data Types
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(hrType)
        }
        if let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(spo2Type)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        if let hrType = HKSampleType.quantityType(forIdentifier: .heartRate) {
            types.insert(hrType)
        }
        if let spo2Type = HKSampleType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(spo2Type)
        }
        if let hrvType = HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        return types
    }()

    // MARK: - Authorization
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
        } catch {
            authorizationError = "HealthKit authorization failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Write Data
    func saveHeartRate(_ bpm: Double, date: Date = Date()) async throws {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.typeNotAvailable
        }

        let quantity = HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: bpm)
        let sample = HKQuantitySample(type: hrType, quantity: quantity, start: date, end: date)

        try await healthStore.save(sample)
    }

    func saveOxygenSaturation(_ spo2: Double, date: Date = Date()) async throws {
        guard let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw HealthKitError.typeNotAvailable
        }

        let quantity = HKQuantity(unit: .percent(), doubleValue: spo2 / 100.0)
        let sample = HKQuantitySample(type: spo2Type, quantity: quantity, start: date, end: date)

        try await healthStore.save(sample)
    }

    func saveHRV(_ hrv: Double, date: Date = Date()) async throws {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.typeNotAvailable
        }

        let quantity = HKQuantity(unit: HKUnit(from: "ms"), doubleValue: hrv)
        let sample = HKQuantitySample(type: hrvType, quantity: quantity, start: date, end: date)

        try await healthStore.save(sample)
    }

    // MARK: - Read Data
    func fetchRecentHeartRates(limit: Int = 50) async throws -> [HKQuantitySample] {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.typeNotAvailable
        }

        return try await fetchSamples(for: hrType, limit: limit)
    }

    func fetchRecentOxygenSaturation(limit: Int = 50) async throws -> [HKQuantitySample] {
        guard let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw HealthKitError.typeNotAvailable
        }

        return try await fetchSamples(for: spo2Type, limit: limit)
    }

    func fetchRecentHRV(limit: Int = 50) async throws -> [HKQuantitySample] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.typeNotAvailable
        }

        return try await fetchSamples(for: hrvType, limit: limit)
    }

    private func fetchSamples(for type: HKQuantityType, limit: Int) async throws -> [HKQuantitySample] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            end: Date(),
            options: .strictEndDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Statistics
    func fetchTodayAverageHeartRate() async throws -> Double? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.typeNotAvailable
        }

        return try await fetchDayAverage(for: hrType, unit: .count().unitDivided(by: .minute()))
    }

    func fetchTodayAverageSpO2() async throws -> Double? {
        guard let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw HealthKitError.typeNotAvailable
        }

        let result = try await fetchDayAverage(for: spo2Type, unit: .percent())
        return result.map { $0 * 100 }
    }

    private func fetchDayAverage(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictEndDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                    continuation.resume(returning: value)
                }
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - HealthKit Error
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case typeNotAvailable
    case saveFailed(Error)
    case fetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device."
        case .notAuthorized: return "HealthKit access has not been authorized."
        case .typeNotAvailable: return "The requested health data type is not available."
        case .saveFailed(let error): return "Failed to save health data: \(error.localizedDescription)"
        case .fetchFailed(let error): return "Failed to fetch health data: \(error.localizedDescription)"
        }
    }
}

// MARK: - HKQuantitySample Extension
extension HKQuantitySample {
    var heartRateBPM: Double {
        quantity.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    var oxygenPercentage: Double {
        quantity.doubleValue(for: .percent()) * 100
    }

    var hrvMilliseconds: Double {
        quantity.doubleValue(for: HKUnit(from: "ms"))
    }
}
