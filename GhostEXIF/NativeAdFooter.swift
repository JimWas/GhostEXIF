import Combine
import GoogleMobileAds
import SwiftUI
import UIKit

private enum AdMobConfiguration {
    static var nativeAdUnitID: String {
        Bundle.main.object(forInfoDictionaryKey: "GADNativeAdUnitIdentifier") as? String
            ?? "ca-app-pub-3940256099942544/3986624511"
    }
}

@MainActor
final class NativeAdLoaderModel: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published private(set) var nativeAd: NativeAd?

    private var adLoader: AdLoader?
    private var hasRequestedAd = false

    func loadIfNeeded() {
        guard !hasRequestedAd, AdMobCoordinator.shared.canRequestAds else { return }
        hasRequestedAd = true

        let loader = AdLoader(
            adUnitID: AdMobConfiguration.nativeAdUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        // Do not immediately retry: Google discourages retry loops on failed requests.
        nativeAd = nil
    }
}

struct NativeAdFooter: View {
    @ObservedObject private var ads = AdMobCoordinator.shared
    @StateObject private var loader = NativeAdLoaderModel()

    var body: some View {
        Group {
            if let nativeAd = loader.nativeAd {
                NativeAdRepresentable(nativeAd: nativeAd)
                    .frame(height: 124)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Sponsored advertisement")
            }
        }
        .task(id: ads.canRequestAds) {
            if ads.canRequestAds {
                loader.loadIfNeeded()
            }
        }
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> CompactNativeAdView {
        CompactNativeAdView()
    }

    func updateUIView(_ view: CompactNativeAdView, context: Context) {
        view.populate(with: nativeAd)
    }
}

private final class CompactNativeAdView: NativeAdView {
    private let mediaAssetView = MediaView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let callToActionButton = UIButton(type: .system)
    private let attributionLabel = UILabel()
    private let choicesView = AdChoicesView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func populate(with ad: NativeAd) {
        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        bodyLabel.isHidden = ad.body == nil
        advertiserLabel.text = ad.advertiser
        advertiserLabel.isHidden = ad.advertiser == nil
        callToActionButton.setTitle(ad.callToAction, for: .normal)
        callToActionButton.isHidden = ad.callToAction == nil
        mediaAssetView.mediaContent = ad.mediaContent

        headlineView = headlineLabel
        bodyView = bodyLabel
        advertiserView = advertiserLabel
        callToActionView = callToActionButton
        mediaView = mediaAssetView
        adChoicesView = choicesView

        ad.rootViewController = Self.topViewController
        nativeAd = ad
    }

    private func configureView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.94)
        layer.borderColor = UIColor(red: 0, green: 1, blue: 0.25, alpha: 0.38).cgColor
        layer.borderWidth = 1
        clipsToBounds = true

        mediaAssetView.translatesAutoresizingMaskIntoConstraints = false
        mediaAssetView.backgroundColor = UIColor(white: 0.06, alpha: 1)
        mediaAssetView.contentMode = .scaleAspectFill
        mediaAssetView.clipsToBounds = true

        attributionLabel.text = "AD"
        attributionLabel.font = .monospacedSystemFont(ofSize: 9, weight: .bold)
        attributionLabel.textColor = UIColor(red: 0, green: 1, blue: 0.85, alpha: 1)
        attributionLabel.layer.borderColor = attributionLabel.textColor.cgColor
        attributionLabel.layer.borderWidth = 1
        attributionLabel.textAlignment = .center
        attributionLabel.translatesAutoresizingMaskIntoConstraints = false

        headlineLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        headlineLabel.textColor = UIColor(red: 0, green: 1, blue: 0.25, alpha: 1)
        headlineLabel.numberOfLines = 1

        advertiserLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        advertiserLabel.textColor = UIColor(red: 0, green: 0.85, blue: 0.8, alpha: 1)
        advertiserLabel.numberOfLines = 1

        bodyLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        bodyLabel.textColor = UIColor(white: 0.78, alpha: 1)
        bodyLabel.numberOfLines = 2

        callToActionButton.titleLabel?.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        callToActionButton.setTitleColor(.black, for: .normal)
        callToActionButton.backgroundColor = UIColor(red: 0, green: 1, blue: 0.25, alpha: 1)
        callToActionButton.isUserInteractionEnabled = false
        callToActionButton.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let titleRow = UIStackView(arrangedSubviews: [attributionLabel, headlineLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 7

        let textStack = UIStackView(arrangedSubviews: [titleRow, advertiserLabel, bodyLabel, callToActionButton])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mediaAssetView)
        addSubview(textStack)
        addSubview(choicesView)
        choicesView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mediaAssetView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            mediaAssetView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            mediaAssetView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            mediaAssetView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.32),

            textStack.leadingAnchor.constraint(equalTo: mediaAssetView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),

            attributionLabel.widthAnchor.constraint(equalToConstant: 25),
            attributionLabel.heightAnchor.constraint(equalToConstant: 17),

            choicesView.topAnchor.constraint(equalTo: mediaAssetView.topAnchor),
            choicesView.trailingAnchor.constraint(equalTo: mediaAssetView.trailingAnchor)
        ])
    }

    private static var topViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
