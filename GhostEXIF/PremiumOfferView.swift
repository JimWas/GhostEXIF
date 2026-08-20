import StoreKit
import SwiftUI

struct PremiumOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchases = PurchaseManager.shared

    private let privacyURL = URL(string: "https://www.jimwashkau.com/privacy")!

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            MatrixBackground()

            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button("NOT_NOW") { dismiss() }
                            .matrixText(size: 11, color: Theme.terminalCyan)
                    }

                    Image(systemName: "crown.fill")
                        .font(.system(size: 54))
                        .foregroundColor(Theme.matrixGreen)
                        .shadow(color: Theme.matrixGreen.opacity(0.8), radius: 12)

                    VStack(spacing: 8) {
                        Text("UNLOCK_GHOSTEXIF_PREMIUM")
                            .matrixText(size: 22, color: Theme.matrixGreen, isHeader: true)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)

                        Text("ONE_TIME_PURCHASE • NO_SUBSCRIPTION")
                            .matrixText(size: 10, color: Theme.terminalCyan)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        benefit(icon: "rectangle.slash", title: "REMOVE_ADVERTISING", detail: "Use GhostEXIF without the native ad on the home screen.")
                        benefit(icon: "checkmark.shield", title: "PERMANENT_PREMIUM_ACCESS", detail: "A verified, non-consumable App Store purchase—not a subscription.")
                        benefit(icon: "arrow.clockwise.icloud", title: "RESTORE_ANY_TIME", detail: "Restore Premium after reinstalling or on compatible devices using the same Apple Account.")
                    }
                    .hackerPanel()

                    Button {
                        Task { await purchases.purchasePremium() }
                    } label: {
                        HStack {
                            Spacer()
                            if purchases.isWorking {
                                ProgressView().tint(.black)
                            } else {
                                Text(unlockTitle)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.vertical, 15)
                        .background(Theme.matrixGreen)
                    }
                    .disabled(purchases.isWorking)

                    Button {
                        Task { await purchases.restorePurchases() }
                    } label: {
                        Text("RESTORE_PURCHASES")
                            .matrixText(size: 12, color: Theme.terminalCyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .border(Theme.terminalCyan.opacity(0.6), width: 1)
                    }
                    .disabled(purchases.isWorking)

                    if let statusMessage = purchases.statusMessage {
                        Text(statusMessage)
                            .matrixText(size: 10, color: purchases.hasPremium ? Theme.matrixGreen : Theme.terminalCyan)
                            .multilineTextAlignment(.center)
                    }

                    Text("Metadata inspection, GPS purge, full wipe, identity tools, resizing, and export remain available in Standard Mode.")
                        .matrixText(size: 9, color: Theme.matrixGreen.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Link("PRIVACY_POLICY", destination: privacyURL)
                        .matrixText(size: 10, color: Theme.terminalCyan)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .interactiveDismissDisabled(purchases.isWorking)
        .onChange(of: purchases.hasPremium) { hasPremium in
            if hasPremium { dismiss() }
        }
    }

    private func benefit(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.matrixGreen)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .matrixText(size: 12, color: Theme.matrixGreen)
                Text(detail)
                    .matrixText(size: 9, color: Theme.terminalCyan)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var unlockTitle: String {
        if let product = purchases.premiumProduct {
            return "UNLOCK_PREMIUM • \(product.displayPrice)"
        }
        return "CHECK_PREMIUM_AVAILABILITY"
    }
}

#Preview {
    PremiumOfferView()
}
