import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ImportedMedia: Identifiable {
    let id = UUID()
    let url: URL
}

struct ImportedMediaBatch: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct PhotoPickerMedia: Transferable, Sendable {
    let url: URL

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            PhotoPickerMedia(url: try MediaFileStore.copyToTemporaryDirectory(from: received.file))
        }
        FileRepresentation(importedContentType: .movie) { received in
            PhotoPickerMedia(url: try MediaFileStore.copyToTemporaryDirectory(from: received.file))
        }
    }
}

enum MediaFileStore {
    nonisolated private static let importDirectoryName = "GhostEXIFImports"

    nonisolated static func copyToTemporaryDirectory(from sourceURL: URL) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(importDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileExtension = sourceURL.pathExtension
        let destination = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    nonisolated static func copySecurityScopedFile(from sourceURL: URL) throws -> URL {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        return try copyToTemporaryDirectory(from: sourceURL)
    }

    /// Removes media files created by GhostEXIF without touching user originals.
    @discardableResult
    nonisolated static func clearTemporaryMediaFiles() throws -> Int {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let importsDirectory = temporaryDirectory
            .appendingPathComponent(importDirectoryName, isDirectory: true)
        var removedFileCount = 0

        if fileManager.fileExists(atPath: importsDirectory.path) {
            removedFileCount += (try? fileManager.contentsOfDirectory(at: importsDirectory, includingPropertiesForKeys: nil).count) ?? 0
            try fileManager.removeItem(at: importsDirectory)
        }

        // Older builds wrote transformed media directly into the app's temporary
        // directory using UUID filenames. Remove only those known media files.
        let legacyFiles = (try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for fileURL in legacyFiles {
            guard UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) != nil,
                  let contentType = UTType(filenameExtension: fileURL.pathExtension),
                  contentType.conforms(to: .image) || contentType.conforms(to: .movie) else {
                continue
            }
            try fileManager.removeItem(at: fileURL)
            removedFileCount += 1
        }

        return removedFileCount
    }
}
