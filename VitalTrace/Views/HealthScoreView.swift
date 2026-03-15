//
//  HealthScoreView.swift
//  VitalTrace
//
//  Daily health score breakdown and history
//

import SwiftUI
import SwiftData
import Charts

struct HealthScoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premiumManager

    @State private var viewModel = HealthScoreViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Score Display
                    MainScoreCard(score: viewModel.todayScore, trend: viewModel.trend)

                    // Score Breakdown
                    if let score = viewModel.todayScore {
                        ScoreBreakdownCard(score: score)
                    } else {
                        EmptyScoreCard()
                    }

                    // Score History Chart (Premium)
                    if premiumManager.isPremium {
                        ScoreHistoryChart(data: viewModel.scoreHistoryChartData)
                    } else {
                        PremiumLockedCard(
                            title: "Score History",
                            description: "Track your health score over time with Premium",
                            onUpgrade: { showPaywall = true }
                        )
                    }

                    // Weekly Average
                    if let weeklyAvg = viewModel.weeklyAverage {
                        WeeklyAverageCard(average: weeklyAvg)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Health Score")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.recalculateScore() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isCalculating)
                }
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Main Score Card
struct MainScoreCard: View {
    let score: HealthScore?
    let trend: ScoreTrend

    private var scoreColor: Color {
        guard let score = score else { return .gray }
        switch score.category {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 16)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat((score?.score ?? 0) / 100))
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: score?.score)

                VStack(spacing: 4) {
                    Text(score?.formattedScore ?? "--")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("/ 100")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(score?.category.rawValue ?? "No Data")
                        .font(.title3.bold())
                        .foregroundStyle(scoreColor)
                    Image(systemName: trend.icon)
                        .foregroundStyle(Color(trend.color))
                    Text(trend.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(score?.category.message ?? "Take measurements to calculate your score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Score Breakdown Card
struct ScoreBreakdownCard: View {
    let score: HealthScore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Breakdown")
                .font(.headline)

            ForEach(score.components) { component in
                ComponentRow(component: component)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal)
    }
}

struct ComponentRow: View {
    let component: ScoreComponent

    private var componentColor: Color {
        switch component.percentage {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: component.icon)
                    .foregroundStyle(componentColor)
                    .frame(width: 20)
                Text(component.name)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f", component.score))
                    .font(.subheadline.bold())
                    .foregroundStyle(componentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(componentColor)
                        .frame(width: geo.size.width * component.percentage / 100, height: 6)
                        .animation(.spring(duration: 0.8), value: component.percentage)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Empty Score Card
struct EmptyScoreCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No health score yet")
                .font(.headline)
            Text("Take heart rate and oxygen measurements to calculate your daily health score.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Score History Chart
struct ScoreHistoryChart: View {
    let data: [ChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score History")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                NoDataPlaceholder()
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Score", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 160)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Weekly Average Card
struct WeeklyAverageCard: View {
    let average: Double

    private var color: Color {
        switch average {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Average")
                    .font(.headline)
                Text("Health Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", average))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    HealthScoreView()
        .environment(PremiumManager())
        .modelContainer(for: [HealthScore.self, HeartRateReading.self, OxygenReading.self], inMemory: true)
}
