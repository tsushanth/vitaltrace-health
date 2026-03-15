//
//  HistoryView.swift
//  VitalTrace
//
//  Health readings history with filtering and export
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @Query(sort: \HeartRateReading.timestamp, order: .reverse) private var allHeartRateReadings: [HeartRateReading]
    @Query(sort: \OxygenReading.timestamp, order: .reverse) private var allOxygenReadings: [OxygenReading]

    @State private var viewModel = HistoryViewModel()
    @State private var selectedSegment = 0
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Reading Type", selection: $selectedSegment) {
                    Text("Heart Rate").tag(0)
                    Text("Blood Oxygen").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Period Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TrendPeriod.allCases, id: \.self) { period in
                            PeriodChip(
                                title: period.displayName,
                                isSelected: viewModel.selectedPeriod == period,
                                onTap: {
                                    viewModel.selectedPeriod = period
                                    viewModel.setModelContext(modelContext)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)

                // Stats Summary
                if selectedSegment == 0 {
                    StatsSummaryBar(
                        average: viewModel.averageHeartRate.map { String(format: "%.0f BPM", $0) },
                        min: viewModel.minHeartRate.map { String(format: "%.0f", $0) },
                        max: viewModel.maxHeartRate.map { String(format: "%.0f", $0) }
                    )
                } else {
                    StatsSummaryBar(
                        average: viewModel.averageSpO2.map { String(format: "%.1f%%", $0) },
                        min: viewModel.minSpO2.map { String(format: "%.1f", $0) },
                        max: nil
                    )
                }

                // Readings List
                if selectedSegment == 0 {
                    readingsList(for: viewModel.filteredHeartRateReadings)
                } else {
                    oxygenReadingsList(for: viewModel.filteredOxygenReadings)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if premiumManager.isPremium {
                            Task { await viewModel.exportData() }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        if !premiumManager.isPremium {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.yellow)
                                        .offset(x: 4, y: -4)
                                }
                        } else {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(viewModel.isExporting)
                }
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let data = viewModel.exportData {
                    ExportSheet(csvData: data)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private func readingsList(for readings: [HeartRateReading]) -> some View {
        if readings.isEmpty {
            emptyState(message: "No heart rate readings for this period")
        } else {
            List {
                ForEach(readings) { reading in
                    HeartRateHistoryRow(reading: reading)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteHeartRateReading(readings[index])
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func oxygenReadingsList(for readings: [OxygenReading]) -> some View {
        if readings.isEmpty {
            emptyState(message: "No oxygen readings for this period")
        } else {
            List {
                ForEach(readings) { reading in
                    OxygenHistoryRow(reading: reading)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteOxygenReading(readings[index])
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Spacer()
    }
}

// MARK: - Period Chip
struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.red : Color(.systemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05), radius: 3, y: 1)
        }
    }
}

// MARK: - Stats Summary Bar
struct StatsSummaryBar: View {
    let average: String?
    let min: String?
    let max: String?

    var body: some View {
        HStack {
            if let avg = average {
                StatPill(label: "Avg", value: avg)
            }
            if let min = min {
                StatPill(label: "Min", value: min)
            }
            if let max = max {
                StatPill(label: "Max", value: max)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - History Row Components
struct HeartRateHistoryRow: View {
    let reading: HeartRateReading

    private var categoryColor: Color {
        switch reading.category {
        case .low: return .blue
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }

    var body: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(.red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(reading.formattedBPM + " BPM")
                    .font(.headline)
                if let hrv = reading.hrv {
                    Text("HRV: \(String(format: "%.0f ms", hrv))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(reading.category.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(categoryColor)
                Text(reading.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct OxygenHistoryRow: View {
    let reading: OxygenReading

    private var categoryColor: Color {
        switch reading.category {
        case .normal: return .green
        case .low: return .yellow
        case .veryLow: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        HStack {
            Image(systemName: "lungs.fill")
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(reading.formattedSpO2)
                    .font(.headline)
                Text("Blood Oxygen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(reading.category.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(categoryColor)
                Text(reading.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export Sheet
struct ExportSheet: View {
    let csvData: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(csvData)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: csvData, subject: Text("VitalTrace Health Data")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    HistoryView()
        .environment(PremiumManager())
        .modelContainer(for: [HeartRateReading.self, OxygenReading.self], inMemory: true)
}
