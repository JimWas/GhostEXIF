import SwiftUI
import PhotosUI
import AppTrackingTransparency

struct MainMenuView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial: Bool = false
    @AppStorage("premiumModeEnabled") private var premiumModeEnabled: Bool = false
    @State private var isShowingTutorial = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isShowingPicker = false
    @State private var isShowingFilePicker = false
    @State private var importedMedia: ImportedMedia?
    @State private var importedBatch: ImportedMediaBatch?
    @State private var isShowingPrivacy = false
    @State private var isShowingSettings = false
    @State private var importError: String?
    @State private var trackingPromptScheduled = false

    var body: some View {
        ZStack {
            MatrixBackground()

            VStack(spacing: 0) {
                headerView

                Spacer()

                VStack(spacing: 24) {
                    terminalHeader(title: "CORE_SYSTEM_ACCESS")

                    VStack(spacing: 16) {
                        MenuButton(title: "EXEC_SWARM_PURGE_PHOTOS", icon: "photo.stack.fill", color: Theme.matrixGreen) {
                            selectedItems = []
                            isShowingPicker = true
                        }

                        MenuButton(title: "EXEC_SINGLE_NODE_IMPORT", icon: "doc.text.magnifyingglass", color: Theme.terminalCyan) {
                            isShowingFilePicker = true
                        }

                    }
                    .padding(.horizontal)
                }
                .hackerPanel()
                .padding(20)

                Spacer()

                if !premiumModeEnabled {
                    NativeAdFooter()
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }

                footerStatus
            }
        }
        .photosPicker(isPresented: $isShowingPicker, selection: $selectedItems, maxSelectionCount: 50, matching: .any(of: [.images, .videos]))
        .onChange(of: selectedItems) { newItems in
            handlePickedItems(newItems)
        }
        .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.image, .movie]) { result in
            handleFileImport(result)
        }
        .fullScreenCover(item: $importedMedia) { media in
            EditorView(mediaURL: media.url)
        }
        .fullScreenCover(item: $importedBatch) { batch in
            BatchProcessorView(urls: batch.urls)
        }
        .fullScreenCover(isPresented: $isShowingTutorial) {
            TutorialView(isPresented: $isShowingTutorial)
                .onDisappear { hasCompletedTutorial = true }
        }
        .onAppear {
            if !hasCompletedTutorial {
                isShowingTutorial = true
            } else {
                requestTrackingAuthorizationIfNeeded()
            }
        }
        .onChange(of: hasCompletedTutorial) { completed in
            if completed {
                requestTrackingAuthorizationIfNeeded()
            } else {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    if !hasCompletedTutorial {
                        isShowingTutorial = true
                    }
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                requestTrackingAuthorizationIfNeeded()
            }
        }
        .sheet(isPresented: $isShowingPrivacy) {
            PrivacySupportView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .onOpenURL { url in
            importExternalFile(url)
        }
        .alert("IMPORT_FAILED", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("ACKNOWLEDGE", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "The selected media could not be imported.")
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GHOST EXIF by JimWas")
                    .matrixText(size: 20, isHeader: true)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("v\(appVersion) • SECURE_METADATA_INTERFACE")
                    .matrixText(size: 10, color: Theme.terminalCyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(Theme.terminalCyan)
                    .frame(width: 32, height: 32)
                    .background(Color.black)
                    .overlay(Rectangle().stroke(Theme.terminalCyan.opacity(0.6), lineWidth: 1))
            }
            .accessibilityLabel("App settings")

            Button {
                isShowingPrivacy = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(Theme.terminalCyan)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Privacy and support")
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .border(Theme.matrixGreen.opacity(0.3), width: 1)
    }

    private var footerStatus: some View {
        HStack {
            Text(premiumModeEnabled ? "MODE: PREMIUM" : "MODE: STANDARD")
            Spacer()
            Text("MEDIA: STAYS_LOCAL")
            Spacer()
            Text("STATUS: READY")
        }
        .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.6))
        .padding(8)
        .background(Color.black)
    }

    private func terminalHeader(title: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().frame(height: 1)
            Text(title)
                .matrixText(size: 11)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Rectangle().frame(height: 1)
        }
        .foregroundColor(Theme.matrixGreen.opacity(0.3))
    }

    private func handlePickedItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        Task {
            var urls: [URL] = []
            for item in items {
                do {
                    if let media = try await item.loadTransferable(type: PhotoPickerMedia.self) {
                        urls.append(media.url)
                    }
                } catch {
                    await MainActor.run {
                        importError = error.localizedDescription
                    }
                }
            }

            await MainActor.run {
                if urls.count == 1 {
                    self.importedMedia = urls.first.map(ImportedMedia.init(url:))
                } else if urls.count > 1 {
                    self.importedBatch = ImportedMediaBatch(urls: urls)
                } else if self.importError == nil {
                    self.importError = "No compatible photo or video data was returned by the picker."
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importExternalFile(url)
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func importExternalFile(_ url: URL) {
        do {
            Haptics.play(.medium)
            importedMedia = ImportedMedia(url: try MediaFileStore.copySecurityScopedFile(from: url))
        } catch {
            importError = error.localizedDescription
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func requestTrackingAuthorizationIfNeeded() {
        guard hasCompletedTutorial,
              !isShowingTutorial,
              scenePhase == .active,
              !trackingPromptScheduled else {
            return
        }

        trackingPromptScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await AdMobCoordinator.shared.gatherConsent()

            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                _ = await ATTrackingManager.requestTrackingAuthorization()
            }

            AdMobCoordinator.shared.startMobileAdsIfAllowed()
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    var color: Color = Theme.matrixGreen
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.play(.medium)
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .layoutPriority(1)
                Spacer(minLength: 6)
                Text("[ RUN ]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .fixedSize()
            }
            .matrixText(size: 12, color: color)
            .padding()
            .background(Color.black)
            .border(color.opacity(0.5), width: 1)
        }
    }
}

#Preview {
    MainMenuView()
}
