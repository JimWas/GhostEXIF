import SwiftUI
import UniformTypeIdentifiers

struct BatchProcessorView: View {
    let urls: [URL]
    @StateObject private var metadataManager = MetadataManager()
    @Environment(\.dismiss) private var dismiss

    @State private var processedCount = 0
    @State private var isProcessing = false
    @State private var logs: [String] = []
    @State private var showCompletion = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScanlineOverlay()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("SWARM_PURGE_PROTOCOL_v1.2")
                        .matrixText(size: 18, isHeader: true)
                    Spacer()
                    if !isProcessing && !showCompletion {
                        Button("[ ABORT ]") { dismiss() }
                            .matrixText(size: 12, color: Theme.errorRed)
                    }
                }
                .padding()

                // Status Panel
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TARGET_NODES:")
                        Spacer()
                        Text("\(urls.count)")
                    }
                    .matrixText(size: 14, color: Theme.terminalCyan)

                    ProgressView(value: Double(processedCount), total: Double(urls.count))
                        .tint(Theme.matrixGreen)
                        .background(Theme.matrixGreen.opacity(0.1))

                    HStack {
                        Text("CLEANED:")
                        Spacer()
                        Text("\(processedCount)/\(urls.count)")
                    }
                    .matrixText(size: 12)
                }
                .hackerPanel()
                .padding(.horizontal)

                // Log Panel
                VStack(alignment: .leading, spacing: 8) {
                    Text("> SYSTEM_LOG")
                        .matrixText(size: 10, color: Theme.matrixGreen.opacity(0.5))

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs, id: \.self) { log in
                                    Text(log)
                                        .matrixText(size: 10, isHeader: false)
                                        .transition(.opacity)
                                }
                            }
                        }
                        .onChange(of: logs) { _ in
                            if let last = logs.last {
                                proxy.scrollTo(last)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .hackerPanel()
                .padding(.horizontal)

                // Action Button
                if !isProcessing && !showCompletion {
                    Button(action: startSwarmPurge) {
                        Text("INITIALIZE_SWARM_PURGE")
                            .matrixText(size: 18, isHeader: true)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.matrixGreen.opacity(0.1))
                            .border(Theme.matrixGreen, width: 2)
                    }
                    .padding()
                } else if showCompletion {
                    Button(action: { dismiss() }) {
                        Text("RETURN_TO_CORE")
                            .matrixText(size: 18, isHeader: true)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.terminalCyan.opacity(0.1))
                            .border(Theme.terminalCyan, width: 2)
                    }
                    .padding()
                }
            }
        }
    }

    private func startSwarmPurge() {
        Haptics.play(.heavy)
        isProcessing = true
        logs.append("AUTHENTICATING_SWARM_CLEARANCE...")

        Task {
            for url in urls {
                let fileName = url.lastPathComponent
                await MainActor.run {
                    Haptics.play(.light)
                    logs.append("CLEANING_NODE: \(fileName)...")
                }

                let utType = UTType(filenameExtension: url.pathExtension) ?? .image
                if let newURL = await metadataManager.stripAll(from: url, type: utType) {
                    do {
                        try await metadataManager.saveToPhotos(url: newURL)
                        await MainActor.run {
                            processedCount += 1
                            logs.append("NODE_SUCCESS: \(fileName) SANITIZED_AND_SAVED.")
                        }
                    } catch {
                        await MainActor.run {
                            logs.append("NODE_FAILURE: \(fileName) \(error.localizedDescription)")
                        }
                    }
                } else {
                    await MainActor.run {
                        logs.append("NODE_FAILURE: \(fileName) ERROR_CODE_403.")
                    }
                }

            }

            await MainActor.run {
                isProcessing = false
                showCompletion = true
                Haptics.success()
                logs.append("SWARM_PURGE_COMPLETE. SYSTEM_SECURED.")
            }
        }
    }
}
