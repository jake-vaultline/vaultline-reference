import Foundation
import CryptoKit

struct ReferenceExportSource: Sendable {
    var id: String
    var filename: String
    var url: URL
}
enum ReferenceExporter {
    static func export(brief: ReferenceBrief, sources: [ReferenceExportSource], directory: URL) throws -> URL {
        let fm = FileManager.default, nonce = UUID().uuidString
        let staging = directory.appendingPathComponent(".Vaultline-Reference-\(nonce).partial")
        let target = directory.appendingPathComponent("Vaultline-Reference-\(nonce)")
        try fm.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            let media = staging.appendingPathComponent("references")
            try fm.createDirectory(at: media, withIntermediateDirectories: false)
            var files: [String: String] = [:], checksums: [String: String] = [:]
            for source in sources {
                try Task.checkCancellation()
                guard source.id != ".", source.id != "..", source.id.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil,
                      URL(fileURLWithPath: source.filename).lastPathComponent == source.filename else {
                    throw ReferenceError.message("Reference identity or filename is unsafe; no package was completed.")
                }
                let name = source.id + "." + URL(fileURLWithPath: source.filename).pathExtension
                let destination = media.appendingPathComponent(name)
                guard fm.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw ReferenceError.message("Export destination could not be created.") }
                let input = try FileHandle(forReadingFrom: source.url), output = try FileHandle(forWritingTo: destination)
                defer { try? input.close(); try? output.close() }
                var hash = SHA256()
                while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty { try Task.checkCancellation(); hash.update(data: chunk); try output.write(contentsOf: chunk) }
                try output.synchronize()
                let path = "references/\(name)"; files[source.id] = path
                checksums[path] = hash.finalize().map { String(format: "%02x", $0) }.joined()
            }
            var manifestBrief = brief
            manifestBrief.references = try brief.references.map { source in
                var entry = source; let pool = (source.selections ?? []) + source.candidates
                entry.candidates = try source.selectedIDs.sorted().map { id in
                    guard let candidate = pool.first(where: { $0.id == id }) else { throw ReferenceError.message("A selected asset record is missing. Refresh or remove it before export.") }
                    return candidate
                }
                entry.selections = entry.candidates; return entry
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
            let manifest = ReferenceManifest(brief: manifestBrief, references: files, checksums: checksums)
            try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
            let rows = manifestBrief.references.flatMap { $0.candidates.map { "- \($0.demo ? "DEMO" : "MEDIA NEXUS") | \($0.sourceAssetID ?? $0.id) | \($0.name) | \($0.source) | \($0.timecode ?? "Timecodes not supplied")\n  \($0.evidence.joined(separator: "; "))\n  Availability: \($0.availability ?? "unknown") · observed \($0.observedAt ?? "not supplied")" } }
            try ("# \(brief.title)\n\n\(brief.notes)\n\nReference-and-selects handoff. Archive originals are not included; resolve IDs in Media Nexus. DEMO records are synthetic. Ranges are asset seconds unless explicitly identified otherwise. Match evidence is retained from selection time; availability may change. manifest.json includes SHA-256 checksums for the reference files.\n\n" + rows.joined(separator: "\n")).write(to: staging.appendingPathComponent("SELECTS.md"), atomically: true, encoding: .utf8)
            try Task.checkCancellation(); try fm.moveItem(at: staging, to: target)
            return target
        } catch { try? fm.removeItem(at: staging); throw error }
    }
}
