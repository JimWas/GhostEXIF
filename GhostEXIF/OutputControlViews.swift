import SwiftUI

struct ProfessionalIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var artist: String
    @State private var copyright: String
    let onCommit: (String, String) -> Void

    init(artist: String, copyright: String, onCommit: @escaping (String, String) -> Void) {
        _artist = State(initialValue: artist)
        _copyright = State(initialValue: copyright)
        self.onCommit = onCommit
    }

    var body: some View {
        editorSheet(title: "PROFESSIONAL_IDENTITY") {
            Text("Adds standard IPTC Artist and Copyright tags. These fields identify the creator or rights holder; they do not alter image pixels.")
                .matrixText(size: 12, color: Theme.terminalCyan)
            labeledField("ARTIST", text: $artist)
            labeledField("COPYRIGHT", text: $copyright)
            commitButton("STAGE_IDENTITY") {
                onCommit(artist, copyright)
                dismiss()
            }
        }
    }
}

struct ResolutionResizeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var widthText: String
    @State private var heightText: String
    @State private var lockAspectRatio = true
    @FocusState private var focusedField: Field?
    private let aspectRatio: Double
    let onCommit: (Int, Int) -> Void

    private enum Field { case width, height }

    init(currentWidth: Int, currentHeight: Int, onCommit: @escaping (Int, Int) -> Void) {
        _widthText = State(initialValue: String(currentWidth))
        _heightText = State(initialValue: String(currentHeight))
        aspectRatio = Double(max(1, currentWidth)) / Double(max(1, currentHeight))
        self.onCommit = onCommit
    }

    var body: some View {
        editorSheet(title: "RESIZE_RESOLUTION") {
            Text("Enter output pixel dimensions. Values must be between 1 and 12,000 pixels.")
                .matrixText(size: 12, color: Theme.terminalCyan)
            labeledField("WIDTH_PX", text: $widthText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .width)
                .onChange(of: widthText) { value in
                    guard lockAspectRatio, focusedField == .width, let width = Int(value) else { return }
                    heightText = String(max(1, Int((Double(width) / aspectRatio).rounded())))
                }
            labeledField("HEIGHT_PX", text: $heightText)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .height)
                .onChange(of: heightText) { value in
                    guard lockAspectRatio, focusedField == .height, let height = Int(value) else { return }
                    widthText = String(max(1, Int((Double(height) * aspectRatio).rounded())))
                }
            Toggle("LOCK_ASPECT_RATIO", isOn: $lockAspectRatio)
                .tint(Theme.matrixGreen)
                .matrixText(size: 12)
            commitButton("RESIZE_AND_SAVE", enabled: dimensionsAreValid) {
                guard let width = Int(widthText), let height = Int(heightText) else { return }
                onCommit(width, height)
                dismiss()
            }
        }
    }

    private var dimensionsAreValid: Bool {
        guard let width = Int(widthText), let height = Int(heightText) else { return false }
        return (1...12_000).contains(width) && (1...12_000).contains(height)
    }
}

struct TargetFileSizeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetKilobytes: String
    let currentBytes: Int
    let onCommit: (Int) -> Void

    init(currentBytes: Int, onCommit: @escaping (Int) -> Void) {
        self.currentBytes = currentBytes
        _targetKilobytes = State(initialValue: String(max(100, currentBytes / 2_000)))
        self.onCommit = onCommit
    }

    var body: some View {
        editorSheet(title: "TARGET_FILE_SIZE") {
            Text("CURRENT: \(currentBytes / 1_000) KB")
                .matrixText(size: 12)
            Text("Creates the highest-quality JPEG at or below the requested maximum. Resolution is reduced only when compression is not enough.")
                .matrixText(size: 12, color: Theme.terminalCyan)
            labeledField("MAX_SIZE_KB", text: $targetKilobytes)
                .keyboardType(.numberPad)
            commitButton("COMPRESS_AND_SAVE", enabled: targetIsValid) {
                guard let kilobytes = Int(targetKilobytes) else { return }
                onCommit(kilobytes * 1_000)
                dismiss()
            }
        }
    }

    private var targetIsValid: Bool {
        guard let kilobytes = Int(targetKilobytes) else { return false }
        return (10...100_000).contains(kilobytes)
    }
}

private func editorSheet<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    NavigationStack {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content()
                }
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func labeledField(_ label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label).matrixText(size: 10, color: Theme.matrixGreen.opacity(0.7))
        TextField("", text: text)
            .matrixText(size: 16)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .overlay(Rectangle().stroke(Theme.matrixGreen.opacity(0.45), lineWidth: 1))
    }
}

private func commitButton(
    _ title: String,
    enabled: Bool = true,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Text(title)
            .matrixText(size: 14)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.matrixGreen.opacity(0.15))
            .overlay(Rectangle().stroke(Theme.matrixGreen.opacity(0.6), lineWidth: 1))
    }
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
}
