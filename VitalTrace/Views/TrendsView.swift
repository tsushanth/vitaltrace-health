//
//  TrendsView.swift
//  VitalTrace
//
//  Health trends and charts visualization
//

import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @State private var viewModel = HistoryViewModel()
    @State private var selectedPeriod: TrendPeriod = .week
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TrendPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedPeriod) { _, newPeriod in
                        viewModel.selectedPeriod = newPeriod
                        viewModel.setModelContext(modelContext)
                    }

                    // Heart Rate Chart
                    TrendChartCard(
                        title: "Heart Rate",
                        subtitle: "BPM over time",
                        icon: "waveform.path.ecg",
                        color: .red,
                        data: viewModel.heartRateChartData,
                        yAxisLabel: "BPM",
                        isPremiumFeature: false
                    )

                    // SpO2 Chart
                    TrendChartCard(
                        title: "Blood Oxygen (SpO2)",
                        subtitle: "% over time",
                        icon: "lungs.fill",
                        color: .blue,
                        data: viewModel.oxygenChartData,
                        yAxisLabel: "%",
                        yDomain: 85...100,
                        isPremiumFeature: false
                    )

                    // HRV Chart (Premium)
                    if premiumManager.isPremium {
                        TrendChartCard(
                            title: "Heart Rate Variability",
                            subtitle: "RMSSD (ms)",
                            icon: "waveform.path",
                            color: .purple,
                            data: viewModel.hrvChartData,
                            yAxisLabel: "ms",
                            isPremiumFeature: false
                        )
                    } else {
                        PremiumLockedCard(
                            title: "Heart Rate Variability",
                            description: "Unlock HRV trends and advanced analytics with Premium",
                            onUpgrade: { showPaywall = true }
                        )
                    }

                    // Summary Statistics
                    TrendsSummarySection(viewModel: viewModel)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Trends")
            .onAppear {
                viewModel.selectedPeriod = selectedPeriod
                viewModel.setModelContext(modelContext)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Trend Chart Card
struct TrendChartCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let data: [ChartDataPoint]
    let yAxisLabel: String
    var yDomain: ClosedRange<Double>? = nil
    let isPremiumFeature: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !data.isEmpty {
                    Text("\(data.count) readings")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if data.isEmpty {
                NoDataPlaceholder()
            } else {
                Chart(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(yAxisLabel, point.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(yAxisLabel, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(yAxisLabel, point.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .if(yDomain != nil) { view in
                    view.chartYScale(domain: yDomain!)
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Premium Locked Card
struct PremiumLockedCard: View {
    let title: String
    let description: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.yellow)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onUpgrade) {
                Label("Unlock Premium", systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.05), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Trends Summary Section
struct TrendsSummarySection: View {
    let viewModel: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                if let avgHR = viewModel.averageHeartRate {
                    SummaryRow(
                        icon: "waveform.path.ecg",
                        color: .red,
                        title: "Average Heart Rate",
                        value: String(format: "%.0f BPM", avgHR)
                    )
                }

                if let avgSpO2 = viewModel.averageSpO2 {
                    SummaryRow(
                        icon: "lungs.fill",
                        color: .blue,
                        title: "Average SpO2",
                        value: String(format: "%.1f%%", avgSpO2)
                    )
                }

                if let minHR = viewModel.minHeartRate, let maxHR = viewModel.maxHeartRate {
                    SummaryRow(
                        icon: "arrow.up.arrow.down",
                        color: .orange,
                        title: "HR Range",
                        value: String(format: "%.0f - %.0f BPM", minHR, maxHR)
                    )
                }

                SummaryRow(
                    icon: "number.circle",
                    color: .green,
                    title: "Total Readings",
                    value: "\(viewModel.totalReadings)"
                )
            }
            .padding(.horizontal)
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - No Data Placeholder
struct NoDataPlaceholder: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.flattrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No data for this period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(height: 120)
    }
}

// MARK: - View Extension for Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    TrendsView()
        .environment(PremiumManager())
        .modelContainer(for: [HeartRateReading.self, OxygenReading.self], inMemory: true)
}
