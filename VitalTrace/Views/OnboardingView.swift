//
//  OnboardingView.swift
//  VitalTrace
//
//  App onboarding flow
//

import SwiftUI
import HealthKit

struct OnboardingView: View {
    @Environment(HealthKitService.self) private var healthKitService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    @State private var isRequestingPermissions = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "heart.fill",
            iconColor: .red,
            title: "Monitor Your Vitals",
            description: "Track your heart rate and blood oxygen (SpO2) using just your iPhone camera — no extra equipment needed.",
            imageName: nil
        ),
        OnboardingPage(
            icon: "waveform.path.ecg",
            iconColor: .red,
            title: "Real-Time Heart Rate",
            description: "Place your finger on the camera to measure your heart rate and heart rate variability (HRV) in 30 seconds.",
            imageName: nil
        ),
        OnboardingPage(
            icon: "lungs.fill",
            iconColor: .blue,
            title: "Blood Oxygen Levels",
            description: "Monitor your SpO2 (blood oxygen saturation) to stay informed about your respiratory health.",
            imageName: nil
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .green,
            title: "Track Your Trends",
            description: "View your health history, spot patterns, and understand how your lifestyle affects your vitals over time.",
            imageName: nil
        ),
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            currentPage = pages.count - 1
                        }
                        .foregroundStyle(.secondary)
                        .padding()
                    }
                }

                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }

                    // Final permission page
                    PermissionsPage(
                        isRequesting: isRequestingPermissions,
                        onComplete: {
                            Task { await requestPermissionsAndComplete() }
                        }
                    )
                    .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0...(pages.count), id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.red : Color.gray.opacity(0.3))
                            .frame(width: currentPage == index ? 10 : 6, height: currentPage == index ? 10 : 6)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 24)

                // Navigation
                VStack(spacing: 12) {
                    if currentPage < pages.count {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func requestPermissionsAndComplete() async {
        isRequestingPermissions = true

        await healthKitService.requestAuthorization()

        AnalyticsService.shared.track(.onboardingCompleted)
        if healthKitService.isAuthorized {
            AnalyticsService.shared.track(.healthKitConnected)
        }

        isRequestingPermissions = false
        hasCompletedOnboarding = true
    }
}

// MARK: - Onboarding Page Data
struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let imageName: String?
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(page.iconColor)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Permissions Page
struct PermissionsPage: View {
    let isRequesting: Bool
    let onComplete: () -> Void

    private let permissions: [(icon: String, title: String, description: String, color: Color)] = [
        ("camera.fill", "Camera Access", "Required to measure heart rate and SpO2 using your camera", .red),
        ("heart.text.square.fill", "HealthKit Access", "Sync your vitals with Apple Health", .red),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("App Permissions")
                    .font(.title.bold())

                Text("VitalTrace needs the following permissions to work properly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                ForEach(permissions, id: \.title) { permission in
                    PermissionRow(
                        icon: permission.icon,
                        title: permission.title,
                        description: permission.description,
                        color: permission.color
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                onComplete()
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Get Started")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    OnboardingView()
        .environment(HealthKitService())
}
