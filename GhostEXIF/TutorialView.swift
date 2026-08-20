import SwiftUI

struct TutorialView: View {
    @Binding var isPresented: Bool
    var onCompletion: () -> Void = {}
    @State private var currentPage = 0

    let pages = [
        TutorialPage(
            title: "INIT_SYSTEM_TRAINING",
            description: "Welcome to EXIF_MATRIX. You have been granted access to a high-level metadata manipulation interface. This tool allows you to decrypt and sanitize hidden data nodes within your media files.",
            icon: "terminal"
        ),
        TutorialPage(
            title: "DATA_SANITIZATION",
            description: "Use the 'PURGE_GPS' command to strip location coordinates or 'WIPE_ALL' to completely scrub a file's digital footprint. Your privacy is paramount: all processing occurs entirely on this device.",
            icon: "shield.shimmer"
        ),
        TutorialPage(
            title: "LOCAL_PROCESSING",
            description: "GhostEXIF never uploads your media. Standard Mode uses Google ads. After training, iOS will ask whether advertising may use your device identifier; choosing Ask App Not to Track still allows non-personalized ads.",
            icon: "lock.iphone"
        )
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScanlineOverlay()

            VStack(spacing: 30) {
                HStack {
                    Text("TRAINING_MODULE_\(currentPage + 1)/\(pages.count)")
                        .matrixText(size: 12, color: Theme.terminalCyan)
                    Spacer()
                    Button(action: completeTutorial) {
                        Text("[ SKIP ]")
                            .matrixText(size: 12, color: Theme.errorRed)
                    }
                }
                .padding()

                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: pages[currentPage].icon)
                        .font(.system(size: 60))
                        .foregroundColor(Theme.matrixGreen)
                        .shadow(color: Theme.matrixGreen, radius: 10)

                    Text(pages[currentPage].title)
                        .matrixText(size: 24, isHeader: true)
                        .multilineTextAlignment(.center)

                    Text(pages[currentPage].description)
                        .matrixText(size: 16)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .hackerPanel()
                .padding()

                Spacer()

                HStack {
                    if currentPage > 0 {
                        Button(action: { currentPage -= 1 }) {
                            Text("< PREV_NODE")
                                .matrixText(size: 14)
                                .padding()
                                .border(Theme.matrixGreen.opacity(0.5))
                        }
                    }

                    Spacer()

                    Button(action: {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            completeTutorial()
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "NEXT_NODE >" : "INITIALIZE_CORE")
                            .matrixText(size: 14, color: Theme.terminalCyan)
                            .padding()
                            .background(Theme.terminalCyan.opacity(0.1))
                            .border(Theme.terminalCyan.opacity(0.5))
                    }
                }
                .padding()
            }
        }
    }

    private func completeTutorial() {
        onCompletion()
        isPresented = false
    }
}

struct TutorialPage {
    let title: String
    let description: String
    let icon: String
}

#Preview {
    TutorialView(isPresented: .constant(true))
}
