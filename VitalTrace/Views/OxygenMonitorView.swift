//
//  OxygenMonitorView.swift
//  VitalTrace
//
//  Camera-based blood oxygen (SpO2) measurement view
//

import SwiftUI
import SwiftData

struct OxygenMonitorView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = MonitorViewModel()
    @State private var showTip = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Finger indicator
                    FingerPlacementIndicator(
                        fingerDetected: viewModel.fingerDetected,
                        state: viewModel.monitorState
                    )

                    // SpO2 Gauge
                    SpO2Gauge(spO2: viewModel.currentSpO2, state: viewModel.monitorState)

                    // Progress
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

                    // Control Buttons
                    controlButtons

                    // Results
                    if viewModel.isCompleted {
                        SpO2ResultsCard(
                            spO2: viewModel.currentSpO2,
                            isSaving: viewModel.isSaving,
                            onSave: {
                                Task { await viewModel.saveCurrentReadings() }
                            }
                        )
                    }

                    // Normal Range Reference
                    SpO2ReferenceCard()

                    if showTip {
                        TipBanner(
                            text: "Cover the camera completely with your fingertip. Avoid moving during measurement for accurate results.",
                            onDismiss: { showTip = false }
                        )
                    }

                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }
                }
                .padding()
            }
            .navigationTitle("Blood Oxygen (SpO2)")
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
                    viewModel.startMeasurement(type: .oxygenSaturation)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
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

// MARK: - SpO2 Gauge
struct SpO2Gauge: View {
    let spO2: Double
    let state: MonitorState

    private var category: OxygenCategory {
        switch spO2 {
        case 95...100: return .normal
        case 90..<95: return .low
        case 85..<90: return .veryLow
        default: return .critical
        }
    }

    private var gaugeColor: Color {
        switch category {
        case .normal: return .green
        case .low: return .yellow
        case .veryLow: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: 200, height: 200)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 160, height: 160)

            VStack(spacing: 4) {
                Image(systemName: "lungs.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text(spO2 > 0 ? String(format: "%.1f", spO2) : "--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(spO2 > 0 ? gaugeColor : .primary)

                Text("%")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if spO2 > 0 {
                    Text(category.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(gaugeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(gaugeColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - SpO2 Results Card
struct SpO2ResultsCard: View {
    let spO2: Double
    let isSaving: Bool
    let onSave: () -> Void

    private var category: OxygenCategory {
        switch spO2 {
        case 95...100: return .normal
        case 90..<95: return .low
        case 85..<90: return .veryLow
        default: return .critical
        }
    }

    private var categoryColor: Color {
        switch category {
        case .normal: return .green
        case .low: return .yellow
        case .veryLow: return .orange
        case .critical: return .red
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

            VStack(spacing: 4) {
                Text(String(format: "%.1f%%", spO2))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(categoryColor)
                Text("Blood Oxygen (SpO2)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(category.advice)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onSave()
            } label: {
                Label(isSaving ? "Saving..." : "Save Reading", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isSaving)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - SpO2 Reference Card
struct SpO2ReferenceCard: View {
    private let ranges: [(range: String, label: String, color: Color)] = [
        ("95-100%", "Normal", .green),
        ("90-94%", "Low", .yellow),
        ("85-89%", "Very Low", .orange),
        ("< 85%", "Critical", .red),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SpO2 Reference Ranges")
                .font(.subheadline.bold())

            ForEach(ranges, id: \.range) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    Text(item.range)
                        .font(.caption.bold())
                    Text("—")
                        .foregroundStyle(.secondary)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Note: This app is not a medical device. Consult a healthcare provider for medical advice.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    OxygenMonitorView()
        .modelContainer(for: [OxygenReading.self], inMemory: true)
}
