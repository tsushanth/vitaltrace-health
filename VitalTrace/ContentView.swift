//
//  ContentView.swift
//  VitalTrace
//
//  Root content view handling onboarding and main tab navigation
//

import SwiftUI

struct ContentView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "heart.fill")
                }
                .tag(0)

            HeartRateMonitorView()
                .tabItem {
                    Label("Heart Rate", systemImage: "waveform.path.ecg")
                }
                .tag(1)

            OxygenMonitorView()
                .tabItem {
                    Label("SpO2", systemImage: "lungs.fill")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(.red)
    }
}

#Preview {
    ContentView()
        .environment(PremiumManager())
        .environment(HealthKitService())
}
