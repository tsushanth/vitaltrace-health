//
//  MonitorViewModel.swift
//  VitalTrace
//
//  ViewModel for heart rate and SpO2 monitoring
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class MonitorViewModel {
    // MARK: - Dependencies
    private let cameraMonitor = CameraHeartRateMonitor()
    private let healthKitService: HealthKitService
    private var modelContext: ModelContext?

    // MARK: - Public State
    var monitorState: MonitorState { cameraMonitor.state }
    var currentBPM: Double { cameraMonitor.currentBPM }
    var currentSpO2: Double { cameraMonitor.currentSpO2 }
    var currentHRV: Double { cameraMonitor.currentHRV }
    var fingerDetected: Bool { cameraMonitor.fingerDetected }
    var measurementProgress: Double { cameraMonitor.measurementProgress }

    var lastHeartRateReading: HeartRateReading?
    var lastOxygenReading: OxygenReading?
    var isSaving: Bool = false
    var errorMessage: String?
    var showSaveSuccess: Bool = false

    var activeMonitorType: MonitorType = .both

    init(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    convenience init() {
        self.init(healthKitService: HealthKitService())
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Camera
    func setupCamera() async {
        await cameraMonitor.setupCamera()
    }

    func startMeasurement(type: MonitorType = .both) {
        activeMonitorType = type
        cameraMonitor.startMeasurement(type: type)
        AnalyticsService.shared.track(.measurementStarted(type: type == .heartRate ? "heart_rate" : "spo2"))
    }

    func stopMeasurement() {
        cameraMonitor.stopMeasurement()
    }

    // MARK: - Save Results
    func saveCurrentReadings() async {
        guard case .completed = monitorState else { return }
        isSaving = true
        errorMessage = nil

        do {
            if activeMonitorType == .heartRate || activeMonitorType == .both {
                let reading = HeartRateReading(
                    bpm: currentBPM,
                    confidence: 0.85,
                    hrv: currentHRV > 0 ? currentHRV : nil
                )
                modelContext?.insert(reading)
                lastHeartRateReading = reading

                try await healthKitService.saveHeartRate(currentBPM)
                if currentHRV > 0 {
                    try await healthKitService.saveHRV(currentHRV)
                }

                AnalyticsService.shared.track(.measurementCompleted(type: "heart_rate", value: currentBPM))
            }

            if activeMonitorType == .oxygenSaturation || activeMonitorType == .both {
                let reading = OxygenReading(spO2: currentSpO2, confidence: 0.85)
                modelContext?.insert(reading)
                lastOxygenReading = reading

                try await healthKitService.saveOxygenSaturation(currentSpO2)
                AnalyticsService.shared.track(.measurementCompleted(type: "spo2", value: currentSpO2))
            }

            try modelContext?.save()
            showSaveSuccess = true
        } catch {
            errorMessage = "Failed to save reading: \(error.localizedDescription)"
        }

        isSaving = false
    }

    // MARK: - Instructions
    var measurementInstructions: String {
        switch monitorState {
        case .idle:
            return "Tap Start to begin measurement"
        case .requestingPermission:
            return "Requesting camera permission..."
        case .permissionDenied:
            return "Camera access required. Please enable in Settings."
        case .warming:
            if !fingerDetected {
                return "Place your finger firmly over the camera and flash"
            }
            return "Warming up... Keep your finger steady"
        case .measuring:
            return "Measuring... Keep your finger steady"
        case .completed:
            return "Measurement complete!"
        case .failed(let message):
            return message
        }
    }

    var canStartMeasurement: Bool {
        switch monitorState {
        case .idle, .failed: return true
        default: return false
        }
    }

    var isCompleted: Bool {
        if case .completed = monitorState { return true }
        return false
    }
}
