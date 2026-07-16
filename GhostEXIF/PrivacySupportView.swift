import SwiftUI

struct PrivacySupportView: View {
    @Environment(\.dismiss) private var dismiss

    private let privacyPolicyURL = URL(string: "https://www.jimwashkau.com/privacy")!
    private let supportEmailURL = URL(string: "mailto:contact@jimwashkau.com?subject=GhostEXIF%20Support")!

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("PRIVACY_PROTOCOL")
                            .matrixText(size: 24, isHeader: true)

                        Text("GhostEXIF processes selected photos and videos on this device. Your media is not uploaded to an advertising service or analytics server.")
                            .matrixText(size: 14)

                        Text("Standard Mode can display Google AdMob native ads. Ad requests may share device, consent, and advertising data with Google and participating ad partners, but never include the photos or videos you select in GhostEXIF. Premium Mode hides ads.")
                            .matrixText(size: 14, color: Theme.terminalCyan)

                        Text("Edited files are saved or shared only when you choose an export action. Originals are not overwritten.")
                            .matrixText(size: 14)

                        Text("The app asks for permission before an advertising identifier may be used for personalized ads or advertising measurement. You can decline without losing access to the metadata tools.")
                            .matrixText(size: 14)

                        Link(destination: privacyPolicyURL) {
                            Label("READ PRIVACY POLICY", systemImage: "hand.raised.fill")
                                .matrixText(size: 14)
                        }

                        Link(destination: supportEmailURL) {
                            Label("CONTACT SUPPORT", systemImage: "envelope.fill")
                                .matrixText(size: 14, color: Theme.terminalCyan)
                        }
                    }
                    .hackerPanel()
                    .padding()
                }
            }
            .navigationTitle("PRIVACY & SUPPORT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PrivacySupportView()
}
