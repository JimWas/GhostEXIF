import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import GhostEXIF

@MainActor
final class GhostEXIFTests: XCTestCase {
    func testTemporaryImportCreatesIndependentCopy() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        try payload.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let copy = try MediaFileStore.copyToTemporaryDirectory(from: source)
        defer { try? FileManager.default.removeItem(at: copy) }

        XCTAssertNotEqual(source, copy)
        XCTAssertEqual(try Data(contentsOf: copy), payload)
    }

    func testStripGPSRemovesLocationButPreservesCameraMetadata() async throws {
        let source = try makeJPEGWithMetadata()
        defer { try? FileManager.default.removeItem(at: source) }

        let manager = MetadataManager()
        let output = await manager.stripGPS(from: source, type: .jpeg)
        let outputURL = try XCTUnwrap(output)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let properties = try metadata(at: outputURL)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
        let tiff = try XCTUnwrap(properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any])
        XCTAssertEqual(tiff[kCGImagePropertyTIFFModel as String] as? String, "Test Camera")
    }

    func testInspectorReloadReflectsPurgedMetadata() async throws {
        let source = try makeJPEGWithMetadata()
        defer { try? FileManager.default.removeItem(at: source) }

        let manager = MetadataManager()
        manager.loadMetadata(from: source, type: .jpeg)
        XCTAssertTrue(manager.fields.contains { $0.name == "Latitude" })

        let output = await manager.stripGPS(from: source, type: .jpeg)
        let outputURL = try XCTUnwrap(output)
        defer { try? FileManager.default.removeItem(at: outputURL) }
        manager.loadMetadata(from: outputURL, type: .jpeg)

        XCTAssertFalse(manager.fields.contains { $0.name == "Latitude" || $0.name == "Longitude" })
        XCTAssertNil(manager.rawMetadata[kCGImagePropertyGPSDictionary as String])
    }

    func testStripAllRemovesGPSAndTIFFDictionaries() async throws {
        let source = try makeJPEGWithMetadata()
        defer { try? FileManager.default.removeItem(at: source) }

        let manager = MetadataManager()
        let output = await manager.stripAll(from: source, type: .jpeg)
        let outputURL = try XCTUnwrap(output)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let properties = try metadata(at: outputURL)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil(properties[kCGImagePropertyTIFFDictionary as String])
    }

    func testStripAllBakesInOrientationBeforeRemovingMetadata() async throws {
        let source = try makeJPEGWithMetadata(width: 2, height: 4, orientation: 6)
        defer { try? FileManager.default.removeItem(at: source) }

        let manager = MetadataManager()
        let output = await manager.stripAll(from: source, type: .jpeg)
        let outputURL = try XCTUnwrap(output)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let properties = try metadata(at: outputURL)
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth as String] as? Int, 4)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight as String] as? Int, 2)
        XCTAssertNil(properties[kCGImagePropertyOrientation as String])
    }

    func testThreatAssessmentReflectsSensitiveFields() {
        let manager = MetadataManager()
        manager.fields = [
            MetadataField(name: "Latitude", value: "1 N", category: "GPS", key: "Latitude", isEditable: true),
            MetadataField(name: "Model", value: "Test Camera", category: "Camera", key: "Model", isEditable: true)
        ]
        XCTAssertEqual(manager.threatLevel, .high)
    }

    func testProfessionalIdentityAddsExportableIPTCTags() async throws {
        let source = try makeJPEGWithMetadata()
        defer { try? FileManager.default.removeItem(at: source) }

        let manager = MetadataManager()
        manager.loadMetadata(from: source, type: .jpeg)
        manager.applyProfessionalIdentity(artist: "Test Artist", copyright: "© Test Owner")

        XCTAssertEqual(manager.fields.first(where: { $0.name == "Artist" })?.value, "Test Artist")
        let output = await manager.applyChanges(to: source)
        let outputURL = try XCTUnwrap(output)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let properties = try metadata(at: outputURL)
        let iptc = try XCTUnwrap(properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any])
        XCTAssertEqual(iptc[kCGImagePropertyIPTCByline as String] as? String, "Test Artist")
        XCTAssertEqual(iptc[kCGImagePropertyIPTCCopyrightNotice as String] as? String, "© Test Owner")
    }

    func testGhostIdentityRemovesUnderlyingIdentityTags() async throws {
        let source = try makeJPEGWithMetadata(includeIdentity: true)
        defer { try? FileManager.default.removeItem(at: source) }

        let manager = MetadataManager()
        manager.loadMetadata(from: source, type: .jpeg)
        manager.applyGhostIdentity()
        let output = await manager.applyChanges(to: source)
        let outputURL = try XCTUnwrap(output)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let properties = try metadata(at: outputURL)
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        XCTAssertNil(tiff[kCGImagePropertyTIFFMake as String])
        XCTAssertNil(tiff[kCGImagePropertyTIFFModel as String])
        XCTAssertNil(tiff[kCGImagePropertyTIFFSoftware as String])
        let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        XCTAssertNil(iptc[kCGImagePropertyIPTCByline as String])
        XCTAssertNil(iptc[kCGImagePropertyIPTCCopyrightNotice as String])
    }

    func testResolutionResizeProducesRequestedDimensions() throws {
        let source = try makeJPEGWithMetadata(width: 20, height: 10)
        defer { try? FileManager.default.removeItem(at: source) }

        let outputURL = try XCTUnwrap(MetadataManager().resizeImage(from: source, width: 8, height: 6))
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let properties = try metadata(at: outputURL)
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth as String] as? Int, 8)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight as String] as? Int, 6)
    }

    func testTargetFileSizeProducesJPEGWithinMaximum() throws {
        let source = try makeJPEGWithMetadata(width: 40, height: 40)
        defer { try? FileManager.default.removeItem(at: source) }

        let outputURL = try XCTUnwrap(MetadataManager().imageMatchingFileSize(from: source, targetBytes: 10_000))
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let size = try XCTUnwrap(outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        XCTAssertEqual(outputURL.pathExtension.lowercased(), "jpg")
        XCTAssertLessThanOrEqual(size, 10_000)
    }

    private func makeJPEGWithMetadata(
        width: Int = 2,
        height: Int = 2,
        orientation: Int? = nil,
        includeIdentity: Bool = false
    ) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        var tiff: [String: Any] = [
            kCGImagePropertyTIFFModel as String: "Test Camera"
        ]
        if includeIdentity {
            tiff[kCGImagePropertyTIFFMake as String] = "Test Make"
            tiff[kCGImagePropertyTIFFSoftware as String] = "Test Software"
        }
        var properties: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: tiff,
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 40.7128,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 74.0060,
                kCGImagePropertyGPSLongitudeRef as String: "W"
            ]
        ]
        if includeIdentity {
            properties[kCGImagePropertyIPTCDictionary as String] = [
                kCGImagePropertyIPTCByline as String: "Original Artist",
                kCGImagePropertyIPTCCopyrightNotice as String: "Original Copyright"
            ]
        }
        if let orientation {
            properties[kCGImagePropertyOrientation as String] = orientation
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func metadata(at url: URL) throws -> [String: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
    }
}
