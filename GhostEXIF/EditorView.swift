import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AVKit
import ImageIO
import UIKit

private struct EditorSnapshot {
    let mediaURL: URL
    let type: UTType
    let fields: [MetadataField]
    let rawMetadata: [String: Any]
}

struct EditorView: View {
    let mediaURL: URL
    @StateObject private var metadataManager = MetadataManager()
    @Environment(\.dismiss) private var dismiss
    @State private var workingMediaURL: URL
    @State private var utType: UTType = .image

    @State private var selectedField: MetadataField?
    @State private var isShowingRawMetadata = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isShowingProfessionalIdentity = false
    @State private var isShowingResolutionResize = false
    @State private var isShowingTargetFileSize = false
    @State private var isProcessing = false
    @State private var stagedHistory: [EditorSnapshot] = []
    @State private var isShowingHomeConfirmation = false
    @State private var previewImage: UIImage?
    @State private var previewLoadFailed = false

    init(mediaURL: URL) {
        self.mediaURL = mediaURL
        _workingMediaURL = State(initialValue: mediaURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left Pane: Visual Scan
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            terminalLabel(title: "VISUAL_SCAN")
                            mediaPreview
                                .frame(height: 180)
                                .hackerPanel(color: Theme.terminalCyan)

                            terminalLabel(title: "THREAT_ASSESSMENT")
                            threatAssessmentPanel

                            terminalLabel(title: "IDENTITY_SPOOF")
                            templatePanel

                            terminalLabel(title: "OUTPUT_CONTROL")
                            outputControlPanel

                            terminalLabel(title: "SYSTEM_COMMANDS")
                            actionButtons
                        }
                    }
                    .frame(width: min(170, max(136, geometry.size.width * 0.4)))
                    .padding()

                    Rectangle()
                        .fill(Theme.matrixGreen.opacity(0.2))
                        .frame(width: 1)

                    // Right Pane: Data Stream
                    VStack(alignment: .leading, spacing: 12) {
                        terminalLabel(title: "METADATA_STREAM_DECODED")

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(metadataManager.fields) { field in
                                    MetadataRow(field: field)
                                        .onTapGesture {
                                            if field.isEditable {
                                                selectedField = field
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }

            bottomStatusLine
        }
        .padding(deviceSafeAreaInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScanlineOverlay().ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .sheet(item: $selectedField) { field in
            EditFieldView(field: field) { newValue in
                metadataManager.updateField(field, newValue: newValue)
            }
        }
        .sheet(isPresented: $isShowingRawMetadata) {
            NavigationStack {
                RawMetadataView(metadata: metadataManager.rawMetadata)
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $isShowingProfessionalIdentity) {
            ProfessionalIdentityView(
                artist: identityValue(named: "Artist"),
                copyright: identityValue(named: "Copyright")
            ) { artist, copyright in
                metadataManager.applyProfessionalIdentity(artist: artist, copyright: copyright)
                alertMessage = "PROFESSIONAL_IDENTITY_STAGED. EXEC_EXPORT WRITES THE TAGS."
                isShowingAlert = true
            }
        }
        .sheet(isPresented: $isShowingResolutionResize) {
            ResolutionResizeView(
                currentWidth: currentPixelWidth,
                currentHeight: currentPixelHeight
            ) { width, height in
                Task { await performResolutionResize(width: width, height: height) }
            }
        }
        .sheet(isPresented: $isShowingTargetFileSize) {
            TargetFileSizeView(currentBytes: currentFileSize) { targetBytes in
                Task { await performTargetFileSize(targetBytes) }
            }
        }
        .alert(alertMessage, isPresented: $isShowingAlert) {
            Button("ACKNOWLEDGE", role: .cancel) { }
        }
        .confirmationDialog(
            "Discard staged privacy changes and return home?",
            isPresented: $isShowingHomeConfirmation,
            titleVisibility: .visible
        ) {
            Button("DISCARD AND RETURN HOME", role: .destructive) { dismiss() }
            Button("CANCEL", role: .cancel) { }
        }
        .onAppear {
            loadMedia()
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: returnHome) {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                    Text("HOME")
                }
                .matrixText(size: 10, color: Theme.errorRed)
            }
            .fixedSize()
            .accessibilityLabel("Return to home screen")
            Spacer()
            Text("DATA_INSPECTOR_SESSION\n#\(String(workingMediaURL.hashValue).suffix(6))")
                .matrixText(size: 11, isHeader: true)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer()
            Button(action: { isShowingRawMetadata = true }) {
                Text("[ RAW_VAL ]")
                    .matrixText(size: 10, color: Theme.terminalCyan)
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black)
        .border(Theme.matrixGreen.opacity(0.3), width: 1)
    }

    private var bottomStatusLine: some View {
        HStack {
            Text("BUFFER: 1024KB")
            Spacer()
            Text(stagedHistory.isEmpty ? "STATUS: READY" : "STATUS: STAGED_\(stagedHistory.count)")
            Spacer()
            Text("NODE: \(workingMediaURL.pathExtension.uppercased())")
        }
        .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.5))
        .padding(6)
        .background(Color.black)
        .border(Theme.matrixGreen.opacity(0.3), width: 1)
    }

    private func terminalLabel(title: String) -> some View {
        Text("> \(title)")
            .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.8))
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if utType.conforms(to: .image) {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
            } else if previewLoadFailed {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                    Text("PREVIEW_UNAVAILABLE")
                        .matrixText(size: 7, color: Theme.errorRed)
                }
                .foregroundColor(Theme.errorRed)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(Theme.matrixGreen)
            }
        } else {
            VideoPlayer(player: AVPlayer(url: workingMediaURL))
        }
    }

    private var threatAssessmentPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metadataManager.threatLevel.rawValue)
                .matrixText(size: 10, color: metadataManager.threatLevel.color, isHeader: true)

            Rectangle()
                .fill(metadataManager.threatLevel.color.opacity(0.3))
                .frame(height: 4)
                .overlay(
                    GeometryReader { geo in
                        Rectangle()
                            .fill(metadataManager.threatLevel.color)
                            .frame(width: geo.size.width * (metadataManager.threatLevel == .high ? 1.0 : (metadataManager.threatLevel == .medium ? 0.6 : 0.2)))
                    }
                )
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .border(metadataManager.threatLevel.color.opacity(0.3), width: 1)
    }

    private var templatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            templateButton(title: "PROFESSIONAL") {
                isShowingProfessionalIdentity = true
            }
            templateButton(title: "GHOST_MODE") {
                metadataManager.applyGhostIdentity()
                alertMessage = "GHOST_MODE_STAGED. DEVICE_AND_CREATOR_IDENTITY_TAGS_WILL_BE_REMOVED_ON_EXPORT."
                isShowingAlert = true
            }
            Text("PROFESSIONAL: add Artist/Copyright. GHOST: remove Make, Model, Software, Artist, and Copyright. Changes are staged until export.")
                .matrixText(size: 7, color: Theme.terminalCyan.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func templateButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.play(.light)
            action()
        }) {
            Text(title)
                .matrixText(size: 8, color: Theme.terminalCyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .border(Theme.terminalCyan.opacity(0.3), width: 1)
        }
    }

    private var outputControlPanel: some View {
        VStack(spacing: 8) {
            templateButton(title: "RESIZE_RESOLUTION") {
                guard utType.conforms(to: .image) else {
                    showError("Resolution resizing currently supports images only.")
                    return
                }
                isShowingResolutionResize = true
            }
            templateButton(title: "TARGET_FILE_SIZE") {
                guard utType.conforms(to: .image) else {
                    showError("Target file size currently supports images only.")
                    return
                }
                isShowingTargetFileSize = true
            }
            if isProcessing {
                ProgressView("PROCESSING")
                    .tint(Theme.matrixGreen)
                    .matrixText(size: 7)
            }
            Text("Target-size output is JPEG and aims for the highest quality at or below the requested size.")
                .matrixText(size: 7, color: Theme.matrixGreen.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            ActionButton(title: "PURGE_GPS", color: Theme.alertAmber) {
                Haptics.play(.heavy)
                Task {
                    let sourceWithEdits = await metadataManager.applyChanges(to: workingMediaURL) ?? workingMediaURL
                    if let newURL = await metadataManager.stripGPS(from: sourceWithEdits, type: utType) {
                        stageProcessedMedia(
                            newURL,
                            message: "LOCATION_DATA_PURGE_STAGED. USE_EXEC_EXPORT_TO_SAVE_OR_UNDO_STAGE_TO_GO_BACK."
                        )
                    } else {
                        showError("Unable to remove location metadata from this file.")
                    }
                }
            }

            ActionButton(title: "WIPE_ALL", color: Theme.errorRed) {
                Haptics.play(.heavy)
                Task {
                    if let newURL = await metadataManager.stripAll(from: workingMediaURL, type: utType) {
                        stageProcessedMedia(
                            newURL,
                            message: "FULL_METADATA_WIPE_STAGED. USE_EXEC_EXPORT_TO_SAVE_OR_UNDO_STAGE_TO_GO_BACK."
                        )
                    } else {
                        showError("Unable to remove metadata from this file.")
                    }
                }
            }

            if !stagedHistory.isEmpty {
                ActionButton(title: "UNDO_STAGE", color: Theme.terminalCyan) {
                    Haptics.play(.light)
                    undoLastStage()
                }
            }

            ActionButton(title: "EXEC_EXPORT", color: Theme.matrixGreen) {
                Haptics.play(.medium)
                Task {
                    if let processedURL = await metadataManager.applyChanges(to: workingMediaURL) {
                        shareItems = [processedURL]
                    } else {
                        shareItems = [workingMediaURL]
                    }
                    isShowingShareSheet = true
                }
            }
        }
    }

    private func loadMedia() {
        if let type = UTType(filenameExtension: workingMediaURL.pathExtension) {
            self.utType = type
            metadataManager.loadMetadata(from: workingMediaURL, type: type)
            loadPreview(for: workingMediaURL, type: type)
        } else {
            previewLoadFailed = true
        }
    }

    private func loadPreview(for url: URL, type: UTType) {
        previewImage = nil
        previewLoadFailed = false
        guard type.conforms(to: .image) else { return }

        Task {
            let data = await Task.detached(priority: .userInitiated) {
                try? Data(contentsOf: url, options: [.mappedIfSafe])
            }.value

            guard url == workingMediaURL else { return }
            previewImage = data.flatMap(UIImage.init(data:))
            previewLoadFailed = previewImage == nil
        }
    }

    private func saveProcessedMedia(_ url: URL, successMessage: String) async {
        let outputType = UTType(filenameExtension: url.pathExtension) ?? utType
        utType = outputType
        workingMediaURL = url
        metadataManager.loadMetadata(from: url, type: outputType)
        loadPreview(for: url, type: outputType)
        do {
            try await metadataManager.saveToPhotos(url: url)
            Haptics.success()
            alertMessage = successMessage
            isShowingAlert = true
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func stageProcessedMedia(_ url: URL, message: String) {
        stagedHistory.append(EditorSnapshot(
            mediaURL: workingMediaURL,
            type: utType,
            fields: metadataManager.fields,
            rawMetadata: metadataManager.rawMetadata
        ))

        let outputType = UTType(filenameExtension: url.pathExtension) ?? utType
        workingMediaURL = url
        utType = outputType
        metadataManager.loadMetadata(from: url, type: outputType)
        loadPreview(for: url, type: outputType)
        alertMessage = message
        isShowingAlert = true
    }

    private func undoLastStage() {
        guard let snapshot = stagedHistory.popLast() else { return }
        workingMediaURL = snapshot.mediaURL
        utType = snapshot.type
        metadataManager.rawMetadata = snapshot.rawMetadata
        metadataManager.fields = snapshot.fields
        loadPreview(for: snapshot.mediaURL, type: snapshot.type)
        alertMessage = stagedHistory.isEmpty
            ? "STAGED_PRIVACY_CHANGES_DISCARDED."
            : "RETURNED_TO_PREVIOUS_STAGE."
        isShowingAlert = true
    }

    private func returnHome() {
        if stagedHistory.isEmpty {
            dismiss()
        } else {
            isShowingHomeConfirmation = true
        }
    }

    private func showError(_ message: String) {
        alertMessage = "ERROR: \(message)"
        isShowingAlert = true
    }

    private var deviceSafeAreaInsets: EdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return EdgeInsets(top: 50, leading: 0, bottom: 34, trailing: 0)
        }
        let insets = window.safeAreaInsets
        return EdgeInsets(
            top: max(insets.top, 8),
            leading: insets.left,
            bottom: max(insets.bottom, 8),
            trailing: insets.right
        )
    }

    private func identityValue(named name: String) -> String {
        metadataManager.fields.first(where: { $0.name == name })?.value ?? ""
    }

    private var currentPixelWidth: Int {
        metadataManager.rawMetadata[kCGImagePropertyPixelWidth as String] as? Int ?? 1
    }

    private var currentPixelHeight: Int {
        metadataManager.rawMetadata[kCGImagePropertyPixelHeight as String] as? Int ?? 1
    }

    private var currentFileSize: Int {
        (try? workingMediaURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    private func performResolutionResize(width: Int, height: Int) async {
        isProcessing = true
        defer { isProcessing = false }
        guard let outputURL = metadataManager.resizeImage(
            from: workingMediaURL,
            width: width,
            height: height
        ) else {
            showError("The image could not be resized to \(width) × \(height).")
            return
        }
        await saveProcessedMedia(
            outputURL,
            successMessage: "RESOLUTION_UPDATED_TO_\(width)×\(height)_AND_SAVED."
        )
    }

    private func performTargetFileSize(_ targetBytes: Int) async {
        isProcessing = true
        defer { isProcessing = false }
        guard let outputURL = metadataManager.imageMatchingFileSize(
            from: workingMediaURL,
            targetBytes: targetBytes
        ) else {
            showError("The requested file size could not be reached. Try a larger target.")
            return
        }
        let actualBytes = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        await saveProcessedMedia(
            outputURL,
            successMessage: "FILE_SIZE_TARGET_COMPLETE_\(actualBytes / 1_000)KB_AND_SAVED."
        )
    }
}

struct MetadataRow: View {
    let field: MetadataField

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(field.name)
                    .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.5))
                Spacer()
                if field.isEditable {
                    Text("[ EDIT ]")
                        .matrixText(size: 8, color: Theme.terminalCyan)
                }
            }
            Text(field.value)
                .matrixText(size: 12)
                .lineLimit(1)
            Rectangle()
                .fill(Theme.matrixGreen.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .matrixText(size: 10, color: color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .border(color.opacity(0.5), width: 1)
        }
    }
}

struct RawMetadataView: View {
    let metadata: [String: Any]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                Text(formatMetadata(metadata))
                    .matrixText(size: 12, color: Theme.terminalCyan)
                    .padding()
            }
        }
        .navigationTitle("RAW_METADATA_STREAM")
    }

    private func formatMetadata(_ dict: [String: Any]) -> String {
        // Simple JSON-like formatting
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else {
            return "Unable to decode stream."
        }
        return str
    }
}
