//
//  HomeView.swift
//  VitalTrace
//
//  Main home dashboard showing latest vitals and health score
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \HeartRateReading.timestamp, order: .reverse) private var heartRateReadings: [HeartRateReading]
    @Query(sort: \OxygenReading.timestamp, order: .reverse) private var oxygenReadings: [OxygenReading]
    @Query(sort: \HealthScore.date, order: .reverse) private var healthScores: [HealthScore]

    @State private var scoreViewModel = HealthScoreViewModel()
    @State private var showPaywall = false

    private var latestHR: HeartRateReading? { heartRateReadings.first }
    private var latestSpO2: OxygenReading? { oxygenReadings.first }
    private var todayScore: HealthScore? { healthScores.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Health Score Card
                    HealthScoreSummaryCard(score: todayScore)

                    // Quick Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        VitalStatCard(
                            title: "Heart Rate",
                            value: latestHR.map { String(format: "%.0f", $0.bpm) } ?? "--",
                            unit: "BPM",
                            icon: "waveform.path.ecg",
                            color: .red,
                            category: latestHR?.category.rawValue ?? "No data"
                        )

                        VitalStatCard(
                            title: "Blood Oxygen",
                            value: latestSpO2.map { String(format: "%.1f", $0.spO2) } ?? "--",
                            unit: "%",
                            icon: "lungs.fill",
                            color: .blue,
                            category: latestSpO2?.category.rawValue ?? "No data"
                        )

                        if let hr = latestHR, let hrv = hr.hrv {
                            VitalStatCard(
                                title: "HRV",
                                value: String(format: "%.0f", hrv),
                                unit: "ms",
                                icon: "waveform.path",
                                color: .purple,
                                category: "Latest"
                            )
                        }

                        VitalStatCard(
                            title: "Readings",
                            value: "\(heartRateReadings.count + oxygenReadings.count)",
                            unit: "total",
                            icon: "chart.bar.fill",
                            color: .green,
                            category: "All time"
                        )
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    QuickActionsSection(showPaywall: $showPaywall, isPremium: premiumManager.isPremium)

                    // Recent Activity
                    if !heartRateReadings.isEmpty || !oxygenReadings.isEmpty {
                        RecentActivitySection(
                            heartRateReadings: Array(heartRateReadings.prefix(3)),
                            oxygenReadings: Array(oxygenReadings.prefix(3))
                        )
                    } else {
                        EmptyStateView()
                    }

                    // HealthKit Banner
                    if !healthKitService.isAuthorized {
                        HealthKitBanner()
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("VitalTrace")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !premiumManager.isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Premium", systemImage: "crown.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
            .onAppear {
                scoreViewModel.setModelContext(modelContext)
                Task { await scoreViewModel.recalculateScore() }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Health Score Summary Card
struct HealthScoreSummaryCard: View {
    let score: HealthScore?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Health Score")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(score?.formattedScore ?? "--")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat((score?.score ?? 0) / 100))
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: score?.category.emoji ?? "heart.circle.fill")
                        .font(.title2)
                        .foregroundStyle(scoreColor)
                }
            }

            Text(score?.category.message ?? "Take a measurement to see your score")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var scoreColor: Color {
        guard let score = score else { return .gray }
        switch score.category {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Vital Stat Card
struct VitalStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let category: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Quick Actions
struct QuickActionsSection: View {
    @Binding var showPaywall: Bool
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink(destination: HeartRateMonitorView()) {
                        QuickActionButton(
                            title: "Measure HR",
                            icon: "waveform.path.ecg",
                            color: .red
                        )
                    }
                    NavigationLink(destination: OxygenMonitorView()) {
                        QuickActionButton(
                            title: "Measure SpO2",
                            icon: "lungs.fill",
                            color: .blue
                        )
                    }
                    NavigationLink(destination: TrendsView()) {
                        QuickActionButton(
                            title: "View Trends",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        )
                    }
                    if !isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            QuickActionButton(
                                title: "Go Premium",
                                icon: "crown.fill",
                                color: .yellow
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}

// MARK: - Recent Activity
struct RecentActivitySection: View {
    let heartRateReadings: [HeartRateReading]
    let oxygenReadings: [OxygenReading]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(heartRateReadings) { reading in
                    RecentReadingRow(
                        icon: "waveform.path.ecg",
                        color: .red,
                        value: String(format: "%.0f BPM", reading.bpm),
                        timestamp: reading.timestamp
                    )
                }
                ForEach(oxygenReadings) { reading in
                    RecentReadingRow(
                        icon: "lungs.fill",
                        color: .blue,
                        value: String(format: "%.1f%%", reading.spO2),
                        timestamp: reading.timestamp
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RecentReadingRow: View {
    let icon: String
    let color: Color
    let value: String
    let timestamp: Date

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32)
            Text(value)
                .font(.subheadline.bold())
            Spacer()
            Text(timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 60))
                .foregroundStyle(.red.opacity(0.5))
            Text("No readings yet")
                .font(.headline)
            Text("Take your first measurement to see your health data here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - HealthKit Banner
struct HealthKitBanner: View {
    @Environment(HealthKitService.self) private var healthKitService

    var body: some View {
        HStack {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(.red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect HealthKit")
                    .font(.subheadline.bold())
                Text("Sync your vitals with Apple Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Connect") {
                Task { await healthKitService.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    HomeView()
        .environment(PremiumManager())
        .environment(HealthKitService())
        .modelContainer(for: [HeartRateReading.self, OxygenReading.self, HealthScore.self], inMemory: true)
}
