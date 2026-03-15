//
//  HistoryViewModel.swift
//  VitalTrace
//
//  ViewModel for health history and trends
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    var selectedPeriod: TrendPeriod = .week
    var selectedReadingType: ReadingType = .heartRate
    var isExporting: Bool = false
    var exportData: String?
    var showExportSheet: Bool = false
    var errorMessage: String?

    // Computed from SwiftData
    var filteredHeartRateReadings: [HeartRateReading] = []
    var filteredOxygenReadings: [OxygenReading] = []

    private var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        refreshData()
    }

    func refreshData() {
        loadHeartRateReadings()
        loadOxygenReadings()
    }

    private func loadHeartRateReadings() {
        guard let context = modelContext else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<HeartRateReading>(
            predicate: #Predicate { $0.timestamp >= cutoff },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        filteredHeartRateReadings = (try? context.fetch(descriptor)) ?? []
    }

    private func loadOxygenReadings() {
        guard let context = modelContext else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<OxygenReading>(
            predicate: #Predicate { $0.timestamp >= cutoff },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        filteredOxygenReadings = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Chart Data
    var heartRateChartData: [ChartDataPoint] {
        filteredHeartRateReadings.map { reading in
            ChartDataPoint(
                date: reading.timestamp,
                value: reading.bpm,
                label: String(format: "%.0f BPM", reading.bpm)
            )
        }.sorted { $0.date < $1.date }
    }

    var oxygenChartData: [ChartDataPoint] {
        filteredOxygenReadings.map { reading in
            ChartDataPoint(
                date: reading.timestamp,
                value: reading.spO2,
                label: String(format: "%.1f%%", reading.spO2)
            )
        }.sorted { $0.date < $1.date }
    }

    var hrvChartData: [ChartDataPoint] {
        filteredHeartRateReadings.compactMap { reading in
            guard let hrv = reading.hrv else { return nil }
            return ChartDataPoint(
                date: reading.timestamp,
                value: hrv,
                label: String(format: "%.1f ms", hrv)
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Statistics
    var averageHeartRate: Double? {
        guard !filteredHeartRateReadings.isEmpty else { return nil }
        return filteredHeartRateReadings.map { $0.bpm }.reduce(0, +) / Double(filteredHeartRateReadings.count)
    }

    var averageSpO2: Double? {
        guard !filteredOxygenReadings.isEmpty else { return nil }
        return filteredOxygenReadings.map { $0.spO2 }.reduce(0, +) / Double(filteredOxygenReadings.count)
    }

    var minHeartRate: Double? {
        filteredHeartRateReadings.map { $0.bpm }.min()
    }

    var maxHeartRate: Double? {
        filteredHeartRateReadings.map { $0.bpm }.max()
    }

    var minSpO2: Double? {
        filteredOxygenReadings.map { $0.spO2 }.min()
    }

    var totalReadings: Int {
        filteredHeartRateReadings.count + filteredOxygenReadings.count
    }

    // MARK: - Export
    func exportData() async {
        isExporting = true

        let csv = DataExporter.exportToCSV(
            heartRateReadings: filteredHeartRateReadings,
            oxygenReadings: filteredOxygenReadings
        )

        self.exportData = csv
        showExportSheet = true
        isExporting = false

        AnalyticsService.shared.track(.exportDataTapped)
    }

    // MARK: - Delete
    func deleteHeartRateReading(_ reading: HeartRateReading) {
        modelContext?.delete(reading)
        try? modelContext?.save()
        refreshData()
    }

    func deleteOxygenReading(_ reading: OxygenReading) {
        modelContext?.delete(reading)
        try? modelContext?.save()
        refreshData()
    }
}
