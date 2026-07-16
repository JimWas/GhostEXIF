import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("premiumModeEnabled") private var premiumModeEnabled = false
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @ObservedObject private var ads = AdMobCoordinator.shared

    @State private var isConfirmingTutorialReset = false
    @State private var isConfirmingFullReset = false
    @State private var resetError: String?

    private let xURL = URL(string: "https://x.com/JimWashkau")!
    private let githubURL = URL(string: "https://github.com/jimwas")!
    private let websiteURL = URL(string: "http://JimWashkau.com")!

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        settingsSection("ACCESS_CONTROL") {
                            Toggle(isOn: $premiumModeEnabled) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("PREMIUM_MODE")
                                        .matrixText(size: 15, color: Theme.matrixGreen)
                                    Text("Device-local premium preference")
                                        .matrixText(size: 10, color: Theme.terminalCyan)
                                }
                            }
                            .tint(Theme.matrixGreen)

                            Text("Premium Mode hides advertising on this device. It is not yet an App Store purchase entitlement.")
                                .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.65))
                        }

                        if ads.isPrivacyOptionsRequired {
                            settingsSection("AD_PRIVACY") {
                                settingsButton("MANAGE_AD_PRIVACY", icon: "hand.raised", color: Theme.terminalCyan) {
                                    Task {
                                        do {
                                            try await ads.presentPrivacyOptions()
                                        } catch {
                                            resetError = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        }

                        settingsSection("RESET_PROTOCOLS") {
                            settingsButton("RESET_TUTORIAL", icon: "arrow.counterclockwise", color: Theme.terminalCyan) {
                                isConfirmingTutorialReset = true
                            }

                            Divider().overlay(Theme.matrixGreen.opacity(0.25))

                            settingsButton("RESET_ALL_SETTINGS_AND_CACHE", icon: "trash", color: .red) {
                                isConfirmingFullReset = true
                            }

                            Text("Clears GhostEXIF preferences and temporary media. Photos and videos in your library are never deleted.")
                                .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.65))
                        }

                        settingsSection("CONNECT_WITH_JIMWAS") {
                            socialLink("x.com/JimWashkau", icon: "at", destination: xURL)
                            socialLink("github.com/jimwas", icon: "chevron.left.forwardslash.chevron.right", destination: githubURL)
                            socialLink("JimWashkau.com", icon: "globe", destination: websiteURL)
                        }

                        Text("GHOST EXIF v\(appVersion)")
                            .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.55))
                    }
                    .padding()
                }
            }
            .navigationTitle("APP_SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") { dismiss() }
                }
            }
            .confirmationDialog("RESET_TUTORIAL?", isPresented: $isConfirmingTutorialReset, titleVisibility: .visible) {
                Button("RESET AND OPEN TUTORIAL") {
                    hasCompletedTutorial = false
                    dismiss()
                }
                Button("CANCEL", role: .cancel) {}
            } message: {
                Text("The onboarding tutorial will open again.")
            }
            .confirmationDialog("RESET ALL APP DATA?", isPresented: $isConfirmingFullReset, titleVisibility: .visible) {
                Button("RESET SETTINGS AND CACHE", role: .destructive) {
                    resetAllSettingsAndCache()
                }
                Button("CANCEL", role: .cancel) {}
            } message: {
                Text("This cannot reset the system's tracking permission. It will not delete anything from Photos.")
            }
            .alert("ACTION_FAILED", isPresented: Binding(
                get: { resetError != nil },
                set: { if !$0 { resetError = nil } }
            )) {
                Button("ACKNOWLEDGE", role: .cancel) { resetError = nil }
            } message: {
                Text(resetError ?? "The cache could not be cleared.")
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .matrixText(size: 12, color: Theme.matrixGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hackerPanel()
    }

    private func settingsButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
            }
            .matrixText(size: 12, color: color)
        }
    }

    private func socialLink(_ title: String, icon: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .matrixText(size: 12, color: Theme.terminalCyan)
        }
    }

    private func resetAllSettingsAndCache() {
        do {
            try MediaFileStore.clearTemporaryMediaFiles()
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            }
            premiumModeEnabled = false
            hasCompletedTutorial = false
            dismiss()
        } catch {
            resetError = error.localizedDescription
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
}
