//
//  HeartRateMonitorView.swift
//  VitalTrace
//
//  Camera-based heart rate measurement view
//

import SwiftUI
import SwiftData

struct HeartRateMonitorView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = MonitorViewModel()
    @State private var showResults = false
    @State private var showTip = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Finger placement indicator
                    FingerPlacementIndicator(
                        fingerDetected: viewModel.fingerDetected,
                        state: viewModel.monitorState
                    )

                    // Main BPM Display
                    HeartRateMeter(
                        bpm: viewModel.currentBPM,
                        state: viewModel.monitorState
                    )

                    // Progress Ring
                    MeasurementProgressRing(
                        progress: viewModel.measurementProgress,
                        state: viewModel.monitorState
                    )

                    // Instructions
                    Text(viewModel.measurementInstructions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // HRV Display (if available)
                    if viewModel.currentHRV > 0 {
                        HRVDisplayCard(hrv: viewModel.currentHRV)
                    }

                    // Control Buttons
                    controlButtons

                    // Results Card
                    if viewModel.isCompleted {
                        ResultsSummaryCard(
                            bpm: viewModel.currentBPM,
                            hrv: viewModel.currentHRV,
                            isSaving: viewModel.isSaving,
                            onSave: {
                                Task { await viewModel.saveCurrentReadings() }
                            }
                        )
                    }

                    // Tip Banner
                    if showTip {
                        TipBanner(
                            text: "For best results, place your index finger firmly over the rear camera lens and flash. Stay still during measurement.",
                            onDismiss: { showTip = false }
                        )
                    }

                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }
                }
                .padding()
            }
            .navigationTitle("Heart Rate")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.setModelContext(modelContext)
                Task { await viewModel.setupCamera() }
            }
            .onDisappear {
                viewModel.stopMeasurement()
            }
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 16) {
            if viewModel.canStartMeasurement {
                Button {
                    viewModel.startMeasurement(type: .heartRate)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else if case .measuring = viewModel.monitorState {
                Button {
                    viewModel.stopMeasurement()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Finger Placement Indicator
struct FingerPlacementIndicator: View {
    let fingerDetected: Bool
    let state: MonitorState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(fingerDetected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
                .scaleEffect(fingerDetected ? 1.0 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: fingerDetected)

            Text(fingerDetected ? "Finger detected" : "Place finger on camera")
                .font(.caption.bold())
                .foregroundStyle(fingerDetected ? .green : .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background((fingerDetected ? Color.green : Color.orange).opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Heart Rate Meter
struct HeartRateMeter: View {
    let bpm: Double
    let state: MonitorState

    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 200, height: 200)
                .scaleEffect(pulsing ? 1.05 : 1.0)

            Circle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 160, height: 160)

            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .scaleEffect(pulsing ? 1.1 : 1.0)

                Text(bpm > 0 ? String(format: "%.0f", bpm) : "--")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("BPM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: bpm) { _, _ in
            triggerPulse()
        }
        .onAppear {
            if case .measuring = state {
                startPulsing()
            }
        }
    }

    private func triggerPulse() {
        withAnimation(.easeInOut(duration: 0.3)) {
            pulsing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                pulsing = false
            }
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
}

// MARK: - Measurement Progress Ring
struct MeasurementProgressRing: View {
    let progress: Double
    let state: MonitorState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                .frame(width: 240, height: 240)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .offset(y: 80)
            }
        }
        .frame(height: 40)
    }
}

// MARK: - HRV Display Card
struct HRVDisplayCard: View {
    let hrv: Double

    var body: some View {
        HStack {
            Image(systemName: "waveform.path")
                .foregroundStyle(.purple)
            Text("HRV")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f ms", hrv))
                .font(.headline.bold())
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Results Summary Card
struct ResultsSummaryCard: View {
    let bpm: Double
    let hrv: Double
    let isSaving: Bool
    let onSave: () -> Void

    var category: HeartRateCategory {
        switch bpm {
        case ..<60: return .low
        case 60...100: return .normal
        case 101...140: return .elevated
        default: return .high
        }
    }

    var categoryColor: Color {
        switch category {
        case .low: return .blue
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Measurement Complete")
                    .font(.headline)
            }

            Divider()

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", bpm))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if hrv > 0 {
                    Divider().frame(height: 50)
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", hrv))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("HRV (ms)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(category.description)
                .font(.subheadline)
                .foregroundStyle(categoryColor)
                .multilineTextAlignment(.center)

            Button {
                onSave()
            } label: {
                Label(isSaving ? "Saving..." : "Save Reading", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isSaving)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Tip Banner
struct TipBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    HeartRateMonitorView()
        .modelContainer(for: [HeartRateReading.self], inMemory: true)
}
