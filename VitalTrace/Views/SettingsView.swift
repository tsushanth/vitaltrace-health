//
//  SettingsView.swift
//  VitalTrace
//
//  App settings and preferences
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(\.modelContext) private var modelContext

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoSaveReadings") private var autoSaveReadings = true
    @AppStorage("measurementDuration") private var measurementDuration = 30
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showExportSheet = false
    @State private var exportCSV = ""
    @State private var isExporting = false

    @Query private var heartRateReadings: [HeartRateReading]
    @Query private var oxygenReadings: [OxygenReading]

    var body: some View {
        NavigationStack {
            List {
                // Premium Section
                Section {
                    if premiumManager.isPremium {
                        PremiumStatusRow()
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            PremiumUpgradeRow()
                        }
                        .buttonStyle(.plain)
                    }
                }

                // HealthKit Section
                Section("Health") {
                    HStack {
                        Label("HealthKit", systemImage: "heart.text.square.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        if healthKitService.isAuthorized {
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Button("Connect") {
                                Task { await healthKitService.requestAuthorization() }
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }

                    NavigationLink(destination: HealthScoreView()) {
                        Label("Health Score", systemImage: "heart.circle.fill")
                    }
                }

                // Measurement Section
                Section("Measurement") {
                    Toggle(isOn: $autoSaveReadings) {
                        Label("Auto-Save Readings", systemImage: "square.and.arrow.down.fill")
                    }
                    .tint(.red)

                    Picker(selection: $measurementDuration) {
                        Text("15 sec").tag(15)
                        Text("30 sec").tag(30)
                        Text("60 sec").tag(60)
                    } label: {
                        Label("Duration", systemImage: "timer")
                    }
                }

                // Data Section
                Section("Data") {
                    HStack {
                        Label("Heart Rate Readings", systemImage: "waveform.path.ecg")
                        Spacer()
                        Text("\(heartRateReadings.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Oxygen Readings", systemImage: "lungs.fill")
                        Spacer()
                        Text("\(oxygenReadings.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        if premiumManager.isPremium {
                            Task { await exportAllData() }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                            if !premiumManager.isPremium {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .disabled(isExporting)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                }

                // Support Section
                Section("Support") {
                    Link(destination: URL(string: "https://vitaltrace.app/support")!) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://vitaltrace.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://vitaltrace.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    Button {
                        Task { await premiumManager.storeKit.restorePurchases() }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }

                    if #available(iOS 17.0, *) {
                        Button("Reset Onboarding") {
                            hasCompletedOnboarding = false
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheet(csvData: exportCSV)
            }
            .confirmationDialog(
                "Delete All Data",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your health readings. This action cannot be undone.")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func exportAllData() async {
        isExporting = true
        exportCSV = DataExporter.exportToCSV(
            heartRateReadings: heartRateReadings,
            oxygenReadings: oxygenReadings
        )
        showExportSheet = true
        isExporting = false
        AnalyticsService.shared.track(.exportDataTapped)
    }

    private func deleteAllData() {
        heartRateReadings.forEach { modelContext.delete($0) }
        oxygenReadings.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Premium Status Row
struct PremiumStatusRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("VitalTrace Premium")
                    .font(.headline)
                Text("All features unlocked")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Premium Upgrade Row
struct PremiumUpgradeRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [.yellow.opacity(0.2), .orange.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Upgrade to Premium")
                    .font(.headline)
                Text("Unlock all features")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environment(PremiumManager())
        .environment(HealthKitService())
        .modelContainer(for: [HeartRateReading.self, OxygenReading.self], inMemory: true)
}
