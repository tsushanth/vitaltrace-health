//
//  VitalTraceApp.swift
//  VitalTrace
//
//  Main app entry point with SwiftData, StoreKit 2, and SDK integrations
//

import SwiftUI
import SwiftData
import HealthKit

@main
struct VitalTraceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer
    @State private var premiumManager = PremiumManager()
    @State private var healthKitService = HealthKitService()

    init() {
        do {
            let schema = Schema([
                VitalReading.self,
                HeartRateReading.self,
                OxygenReading.self,
                HealthTrend.self,
                HealthScore.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(premiumManager)
                .environment(healthKitService)
                .onAppear {
                    Task {
                        await premiumManager.refreshPremiumStatus()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Analytics
        Task { @MainActor in
            AnalyticsService.shared.initialize()
            AnalyticsService.shared.track(.appOpen)
        }

        // Request ATT permission
        Task { @MainActor in
            _ = await ATTService.shared.requestIfNeeded()
            await AttributionManager.shared.requestAttributionIfNeeded()
        }

        return true
    }
}

// MARK: - Premium Manager
@MainActor
@Observable
final class PremiumManager {
    private(set) var isPremium: Bool = false
    private let storeKitManager = StoreKitManager()

    var storeKit: StoreKitManager { storeKitManager }

    func refreshPremiumStatus() async {
        await storeKitManager.updatePurchasedProducts()
        isPremium = storeKitManager.isPremium
    }
}
