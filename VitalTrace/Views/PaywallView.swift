//
//  PaywallView.swift
//  VitalTrace
//
//  Premium subscription paywall
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumManager.self) private var premiumManager

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var storeKit: StoreKitManager { premiumManager.storeKit }

    private let premiumFeatures: [(icon: String, title: String, description: String)] = [
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Detailed HRV analysis and trend insights"),
        ("clock.fill", "Unlimited History", "Keep all your readings forever"),
        ("doc.richtext.fill", "PDF Reports", "Export comprehensive health reports"),
        ("bell.badge.fill", "Smart Alerts", "Get notified when readings are abnormal"),
        ("icloud.fill", "Cloud Backup", "Sync data across all your devices"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    PaywallHeader()

                    // Features List
                    VStack(spacing: 12) {
                        ForEach(premiumFeatures, id: \.title) { feature in
                            FeatureRow(
                                icon: feature.icon,
                                title: feature.title,
                                description: feature.description
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Products
                    if storeKit.isLoading {
                        ProgressView("Loading plans...")
                            .padding()
                    } else if storeKit.allProducts.isEmpty {
                        VStack(spacing: 8) {
                            Text("Unable to load subscription plans")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await storeKit.loadProducts() }
                            }
                        }
                        .padding()
                    } else {
                        ProductsSection(
                            products: storeKit.subscriptions + storeKit.nonConsumables,
                            selectedProduct: $selectedProduct
                        )
                    }

                    // Purchase Button
                    VStack(spacing: 12) {
                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "crown.fill")
                                    Text(selectedProduct != nil ? "Start Premium" : "Select a Plan")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .controlSize(.large)
                        .disabled(selectedProduct == nil || isPurchasing)

                        Button("Restore Purchases") {
                            Task { await storeKit.restorePurchases() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Legal
                    LegalFooter()
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("VitalTrace Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                AnalyticsService.shared.track(.paywallViewed)
                if storeKit.allProducts.isEmpty {
                    Task { await storeKit.loadProducts() }
                }
                // Pre-select yearly if available
                selectedProduct = storeKit.allProducts.first { $0.isPopular }
                    ?? storeKit.allProducts.first
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .onChange(of: storeKit.purchaseState) { _, state in
                if case .purchased = state {
                    Task {
                        await premiumManager.refreshPremiumStatus()
                        dismiss()
                    }
                }
            }
        }
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        AnalyticsService.shared.track(.purchaseStarted(productID: product.id))

        do {
            _ = try await storeKit.purchase(product)
            AnalyticsService.shared.track(.purchaseCompleted(productID: product.id))
        } catch StoreKitError.userCancelled {
            // User cancelled, no action needed
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            AnalyticsService.shared.track(.purchaseFailed(productID: product.id, error: error.localizedDescription))
        }

        isPurchasing = false
    }
}

// MARK: - Paywall Header
struct PaywallHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 8) {
                Text("VitalTrace Premium")
                    .font(.title.bold())

                Text("Unlock the complete health monitoring experience with advanced analytics and unlimited features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 36, height: 36)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Products Section
struct ProductsSection: View {
    let products: [Product]
    @Binding var selectedProduct: Product?

    var body: some View {
        VStack(spacing: 10) {
            ForEach(products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    onSelect: { selectedProduct = product }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.headline)
                        if product.isPopular {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    if let savings = product.savingsLabel {
                        Text(savings)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline.bold())
                    Text(product.periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .gray)
                    .font(.title3)
                    .padding(.leading, 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.red : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.red.opacity(0.15) : Color.black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legal Footer
struct LegalFooter: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Subscriptions auto-renew unless cancelled 24 hours before the renewal date. You can manage subscriptions in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Privacy Policy") {
                    if let url = URL(string: "https://vitaltrace.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Terms of Use") {
                    if let url = URL(string: "https://vitaltrace.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    PaywallView()
        .environment(PremiumManager())
}
