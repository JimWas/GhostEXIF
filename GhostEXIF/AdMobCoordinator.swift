import Combine
import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdMobCoordinator: NSObject, ObservableObject {
    static let shared = AdMobCoordinator()

    @Published private(set) var canRequestAds = false
    @Published private(set) var isPrivacyOptionsRequired = false

    private var hasGatheredConsentThisLaunch = false
    private var hasStartedMobileAds = false

    /// Refreshes UMP consent once per launch. Call this before resolving ATT and starting ads.
    func gatherConsent() async {
        guard !hasGatheredConsentThisLaunch else {
            updatePrivacyState()
            return
        }
        hasGatheredConsentThisLaunch = true

        let parameters = RequestParameters()
        let requestError: Error? = await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }

        if requestError == nil {
            try? await ConsentForm.loadAndPresentIfRequired(from: nil)
        }

        updatePrivacyState()
    }

    /// Starts Google Mobile Ads once, and only after UMP allows ad requests.
    func startMobileAdsIfAllowed() {
        guard ConsentInformation.shared.canRequestAds else {
            canRequestAds = false
            return
        }

        if !hasStartedMobileAds {
            hasStartedMobileAds = true
            MobileAds.shared.start()
        }
        canRequestAds = true
    }

    func presentPrivacyOptions() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        updatePrivacyState()
    }

    private func updatePrivacyState() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
}
