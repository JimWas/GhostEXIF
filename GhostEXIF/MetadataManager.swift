import Foundation
import Combine
import SwiftUI
import CoreLocation
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
import Photos

struct MetadataField: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var value: String
    let category: String
    let key: String // Internal key for editing
    let isEditable: Bool
}

enum ThreatLevel: String {
    case low = "LOW_RISK"
    case medium = "MEDIUM_RISK"
    case high = "CRITICAL_THREAT"

    var color: Color {
        switch self {
        case .low: return Theme.threatLow
        case .medium: return Theme.threatMedium
        case .high: return Theme.threatHigh
        }
    }
}

enum MetadataProcessingError: LocalizedError {
    case unsupportedMediaType
    case photoLibrarySaveFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedMediaType:
            return "The processed file is not a supported photo or video."
        case .photoLibrarySaveFailed:
            return "Photos could not save the processed file. Check Photos access in Settings and try again."
        }
    }
}

class MetadataManager: ObservableObject {
    @Published var fields: [MetadataField] = [] {
        didSet {
            self.threatLevel = calculateThreatLevel()
        }
    }
    @Published var rawMetadata: [String: Any] = [:]
    @Published var threatLevel: ThreatLevel = .low

    func calculateThreatLevel() -> ThreatLevel {
        var score = 0
        let names = fields.map { $0.name }

        if names.contains("Latitude") || names.contains("Longitude") { score += 5 }
        if names.contains("Model") || names.contains("Make") { score += 2 }
        if names.contains("Date Created") { score += 2 }
        if names.contains("Software") { score += 1 }

        if score >= 7 { return .high }
        if score >= 4 { return .medium }
        return .low
    }

    func applyProfessionalIdentity(artist: String, copyright: String) {
        upsertIdentityField(
            name: "Artist",
            value: artist,
            key: kCGImagePropertyIPTCByline as String
        )
        upsertIdentityField(
            name: "Copyright",
            value: copyright,
            key: kCGImagePropertyIPTCCopyrightNotice as String
        )
    }

    func applyGhostIdentity() {
        let identityFieldNames = Set(["Make", "Model", "Software", "Artist", "Copyright"])
        fields.removeAll { identityFieldNames.contains($0.name) }
    }

    private func upsertIdentityField(name: String, value: String, key: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = fields.firstIndex(where: { $0.name == name }) {
            if trimmedValue.isEmpty {
                fields.remove(at: index)
            } else {
                fields[index].value = trimmedValue
            }
        } else if !trimmedValue.isEmpty {
            fields.append(MetadataField(
                name: name,
                value: trimmedValue,
                category: "Copyright",
                key: key,
                isEditable: true
            ))
        }
    }

    func loadMetadata(from url: URL, type: UTType) {
        fields = []
        rawMetadata = [:]
        originalFields = []
        if type.conforms(to: .image) {
            loadImageMetadata(from: url)
        } else if type.conforms(to: .movie) {
            loadVideoMetadata(from: url)
        }
    }

    private func loadImageMetadata(from url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return
        }

        self.rawMetadata = metadata
        self.fields = parseImageMetadata(metadata)
    }

    private func loadVideoMetadata(from url: URL) {
        let asset = AVAsset(url: url)
        Task {
            let metadata = try? await asset.load(.metadata)
            let parsed = await self.parseVideoMetadata(metadata ?? [])
            self.originalFields = parsed
            self.fields = parsed
        }
    }

    private var originalFields: [MetadataField] = []

    func resetChanges() {
        self.fields = originalFields
    }

    private func parseImageMetadata(_ dict: [String: Any]) -> [MetadataField] {
        var parsed: [MetadataField] = []

        // General
        if let width = dict[kCGImagePropertyPixelWidth as String] as? Int,
           let height = dict[kCGImagePropertyPixelHeight as String] as? Int {
            parsed.append(MetadataField(name: "Dimensions", value: "\(width) x \(height)", category: "General", key: "", isEditable: false))
        }

        // TIFF (Make, Model, Software)
        if let tiff = dict[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
                parsed.append(MetadataField(name: "Make", value: make, category: "Camera", key: kCGImagePropertyTIFFMake as String, isEditable: true))
            }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
                parsed.append(MetadataField(name: "Model", value: model, category: "Camera", key: kCGImagePropertyTIFFModel as String, isEditable: true))
            }
            if let software = tiff[kCGImagePropertyTIFFSoftware as String] as? String {
                parsed.append(MetadataField(name: "Software", value: software, category: "Camera", key: kCGImagePropertyTIFFSoftware as String, isEditable: true))
            }
        }

        // EXIF
        if let exif = dict[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let date = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                parsed.append(MetadataField(name: "Date Created", value: date, category: "EXIF", key: kCGImagePropertyExifDateTimeOriginal as String, isEditable: true))
            }
            if let exposure = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                parsed.append(MetadataField(name: "Exposure", value: "\(exposure)s", category: "EXIF", key: "", isEditable: false))
            }
            if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double {
                parsed.append(MetadataField(name: "F-Number", value: "f/\(fNumber)", category: "EXIF", key: "", isEditable: false))
            }
        }

        // IPTC (Copyright, Artist)
        if let iptc = dict[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            if let artist = iptc[kCGImagePropertyIPTCByline as String] as? String {
                parsed.append(MetadataField(name: "Artist", value: artist, category: "Copyright", key: kCGImagePropertyIPTCByline as String, isEditable: true))
            }
            if let copyright = iptc[kCGImagePropertyIPTCCopyrightNotice as String] as? String {
                parsed.append(MetadataField(name: "Copyright", value: copyright, category: "Copyright", key: kCGImagePropertyIPTCCopyrightNotice as String, isEditable: true))
            }
        }

        // GPS
        if let gps = dict[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                parsed.append(MetadataField(name: "Latitude", value: "\(lat) \(latRef)", category: "GPS", key: kCGImagePropertyGPSLatitude as String, isEditable: true))
            }
            if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                parsed.append(MetadataField(name: "Longitude", value: "\(lon) \(lonRef)", category: "GPS", key: kCGImagePropertyGPSLongitude as String, isEditable: true))
            }
        }

        self.originalFields = parsed
        return parsed
    }

    private func parseVideoMetadata(_ metadata: [AVMetadataItem]) async -> [MetadataField] {
        var parsed: [MetadataField] = []
        for item in metadata {
            if let key = item.commonKey?.rawValue,
               let value = try? await item.load(.value) {
                parsed.append(MetadataField(name: key, value: "\(value)", category: "Common", key: key, isEditable: false))
            }
        }
        return parsed
    }

    func stripGPS(from url: URL, type: UTType) async -> URL? {
        if type.conforms(to: .image) {
            return stripImageGPS(from: url)
        } else {
            return await stripVideoMetadata(from: url, stripAll: false)
        }
    }

    func stripAll(from url: URL, type: UTType) async -> URL? {
        if type.conforms(to: .image) {
            return stripImageAll(from: url)
        } else {
            return await stripVideoMetadata(from: url, stripAll: true)
        }
    }

    private func stripVideoMetadata(from url: URL, stripAll: Bool) async -> URL? {
        let asset = AVAsset(url: url)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { return nil }

        let useMP4 = url.pathExtension.lowercased() == "mp4" && exportSession.supportedFileTypes.contains(.mp4)
        let outputType: AVFileType = useMP4 ? .mp4 : .mov
        let outputExtension = useMP4 ? "mp4" : "mov"
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(outputExtension)

        exportSession.outputURL = destURL
        exportSession.outputFileType = outputType
        exportSession.shouldOptimizeForNetworkUse = false

        if stripAll {
            exportSession.metadata = []
        } else {
            let metadata = try? await asset.load(.metadata)
            exportSession.metadata = metadata?.filter { item in
                let commonKeyIsLocation = item.commonKey == .commonKeyLocation
                let identifierIsLocation = item.identifier?.rawValue.localizedCaseInsensitiveContains("location") == true
                return !commonKeyIsLocation && !identifierIsLocation
            }
        }

        await exportSession.export()
        return exportSession.status == .completed ? destURL : nil
    }

    func updateField(_ field: MetadataField, newValue: String) {
        if let index = fields.firstIndex(where: { $0.id == field.id }) {
            fields[index].value = newValue
        }
    }

    private func stripImageGPS(from url: URL) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        metadata.removeValue(forKey: kCGImagePropertyGPSDictionary as String)

        return writeImage(image, from: source, sourceURL: url, properties: metadata)
    }

    private func stripImageAll(from url: URL) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = visuallyOrientedImage(from: source) else { return nil }

        return writeImage(image, from: source, sourceURL: url, properties: nil)
    }

    private func visuallyOrientedImage(from source: CGImageSource) -> CGImage? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        let width = properties?[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        let maximumDimension = max(width, height)
        guard maximumDimension > 0 else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func applyChanges(to url: URL) async -> URL? {
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true {
            return url
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]

        // Treat the inspector as the source of truth for identity fields so Ghost Mode
        // removes the underlying tags instead of merely hiding them in the UI.
        var tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel, kCGImagePropertyTIFFSoftware]
            .forEach { tiff.removeValue(forKey: $0 as String) }
        for field in fields where field.category == "Camera" && field.isEditable {
            tiff[field.key] = field.value
        }
        if tiff.isEmpty {
            metadata.removeValue(forKey: kCGImagePropertyTIFFDictionary as String)
        } else {
            metadata[kCGImagePropertyTIFFDictionary as String] = tiff
        }

        var iptc = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        [kCGImagePropertyIPTCByline, kCGImagePropertyIPTCCopyrightNotice]
            .forEach { iptc.removeValue(forKey: $0 as String) }
        for field in fields where field.category == "Copyright" && field.isEditable {
            iptc[field.key] = field.value
        }
        if iptc.isEmpty {
            metadata.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)
        } else {
            metadata[kCGImagePropertyIPTCDictionary as String] = iptc
        }

        // Map fields back to dictionaries
        for field in fields where field.isEditable {
            switch field.category {
            case "EXIF":
                var exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
                exif[field.key] = field.value
                metadata[kCGImagePropertyExifDictionary as String] = exif
            case "GPS":
                var gps = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
                if let val = Double(field.value.components(separatedBy: " ").first ?? "") {
                    gps[field.key] = val
                }
                metadata[kCGImagePropertyGPSDictionary as String] = gps
            default:
                break
            }
        }

        return writeImage(image, from: source, sourceURL: url, properties: metadata)
    }

    func resizeImage(from url: URL, width: Int, height: Int) -> URL? {
        guard (1...12_000).contains(width),
              (1...12_000).contains(height),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = visuallyOrientedImage(from: source),
              let resizedImage = renderScaledImage(image, width: width, height: height) else {
            return nil
        }

        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        removeOrientationMetadata(from: &metadata)
        return writeImage(resizedImage, from: source, sourceURL: url, properties: metadata)
    }

    /// Creates the highest-quality JPEG that does not exceed `targetBytes`.
    /// Resolution is reduced only when JPEG compression alone cannot reach the target.
    func imageMatchingFileSize(from url: URL, targetBytes: Int) -> URL? {
        guard targetBytes >= 10_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let originalImage = visuallyOrientedImage(from: source) else {
            return nil
        }

        var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        removeOrientationMetadata(from: &metadata)
        metadata.removeValue(forKey: kCGImagePropertyPNGDictionary as String)

        var width = originalImage.width
        var height = originalImage.height
        for _ in 0..<12 {
            guard let candidateImage = renderScaledImage(
                originalImage,
                width: width,
                height: height,
                opaque: true
            ) else { return nil }

            var lowerQuality = 0.35
            var upperQuality = 0.95
            var bestData: Data?
            for _ in 0..<12 {
                let quality = (lowerQuality + upperQuality) / 2
                guard let data = jpegData(
                    for: candidateImage,
                    properties: metadata,
                    quality: quality
                ) else { return nil }

                if data.count <= targetBytes {
                    bestData = data
                    lowerQuality = quality
                } else {
                    upperQuality = quality
                }
            }

            if let bestData {
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")
                do {
                    try bestData.write(to: outputURL, options: .atomic)
                    return outputURL
                } catch {
                    return nil
                }
            }

            guard let minimumQualityData = jpegData(
                for: candidateImage,
                properties: metadata,
                quality: 0.35
            ) else { return nil }
            let ratio = min(0.9, sqrt(Double(targetBytes) / Double(minimumQualityData.count)) * 0.92)
            let nextWidth = max(1, Int(Double(width) * ratio))
            let nextHeight = max(1, Int(Double(height) * ratio))
            guard nextWidth < width || nextHeight < height else { return nil }
            width = nextWidth
            height = nextHeight
        }
        return nil
    }

    private func removeOrientationMetadata(from metadata: inout [String: Any]) {
        metadata.removeValue(forKey: kCGImagePropertyOrientation as String)
        guard var tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] else {
            return
        }
        tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation as String)
        if tiff.isEmpty {
            metadata.removeValue(forKey: kCGImagePropertyTIFFDictionary as String)
        } else {
            metadata[kCGImagePropertyTIFFDictionary as String] = tiff
        }
    }

    private func renderScaledImage(
        _ image: CGImage,
        width: Int,
        height: Int,
        opaque: Bool = false
    ) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        if opaque {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func jpegData(
        for image: CGImage,
        properties: [String: Any],
        quality: Double
    ) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        var outputProperties = properties
        outputProperties[kCGImageDestinationLossyCompressionQuality as String] = quality
        CGImageDestinationAddImage(destination, image, outputProperties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    private func writeImage(
        _ image: CGImage,
        from source: CGImageSource,
        sourceURL: URL,
        properties: [String: Any]?
    ) -> URL? {
        guard let type = CGImageSourceGetType(source) else { return nil }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension)
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary?)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: destinationURL)
            return nil
        }
        return destinationURL
    }

    func saveToPhotos(url: URL) async throws {
        guard let type = UTType(filenameExtension: url.pathExtension),
              type.conforms(to: .image) || type.conforms(to: .movie) else {
            throw MetadataProcessingError.unsupportedMediaType
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                if type.conforms(to: .movie) {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? MetadataProcessingError.photoLibrarySaveFailed)
                }
            }
        }
    }
}
