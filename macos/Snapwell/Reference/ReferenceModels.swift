// Vaultline Reference — GPL-3.0-or-later. Upstream Snapwell notices remain in LICENSE.
import Foundation

struct ReferenceAttribute: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var value: String = ""
    var matters: Bool = true
    var interpretation: Bool { id == "mood" }
    static var empty: [Self] {
        ["subject", "setting", "framing", "lighting", "color palette", "camera movement", "mood"].map { Self(id: $0) }
    }
}
struct ArchiveCandidate: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var source: String
    var thumbnail: String?
    var timecode: String? // Only supplied, verified ranges. Never derived from match text.
    var evidence: [String]
    var demo: Bool
}
struct ReferenceEntry: Codable, Equatable {
    var mediaID: String
    var attributes = ReferenceAttribute.empty
    var analysisOrigin = "Not analyzed — enter observations manually or configure a provider."
    var candidates: [ArchiveCandidate] = []
    var selectedIDs: Set<String> = []
    var searchOrigin: String?
}
struct ReferenceBrief: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title = "Untitled brief"
    var notes = ""
    var references: [ReferenceEntry] = []
}
struct ReferenceManifest: Codable {
    let format = "vaultline-reference-package/v1"
    var exportedAt = Date()
    var brief: ReferenceBrief
    var references: [String: String]
    let scope = "Reference media and evidence-backed select identifiers; archive originals are not included. Demo selects are synthetic."
}

enum ReferenceMatching {
    static func tokens(_ attributes: [ReferenceAttribute]) -> [String] {
        Array(Set(attributes.filter { $0.matters }.flatMap {
            $0.value.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        }.filter { $0.count > 2 && !["the", "and", "with", "unknown", "unobserved"].contains($0) })).sorted()
    }
    static func demoMatches(_ attributes: [ReferenceAttribute], assets: [DemoAsset]) -> [ArchiveCandidate] {
        let terms = tokens(attributes)
        guard !terms.isEmpty else { return [] }
        return assets.compactMap { asset -> ArchiveCandidate? in
            let matches = asset.metadata.keys.sorted().compactMap { field -> String? in
                let value = asset.metadata[field]!
                let found = terms.filter { value.lowercased().split { !$0.isLetter && !$0.isNumber }.contains(Substring($0)) }
                return found.isEmpty ? nil : "Fixture \(field): \(value) (matches \(found.joined(separator: ", ")))."
            }
            guard !matches.isEmpty else { return nil }
            return ArchiveCandidate(id: asset.id, name: asset.name, source: asset.source,
                                    thumbnail: asset.thumbnail, timecode: asset.timecode, evidence: matches, demo: true)
        }.sorted { $0.evidence.count == $1.evidence.count ? $0.id < $1.id : $0.evidence.count > $1.evidence.count }
    }
}
struct DemoAsset: Codable {
    var id: String
    var name: String
    var source: String
    var thumbnail: String
    var timecode: String?
    var metadata: [String: String]
}

protocol ArchiveAdapter: Sendable {
    var label: String { get }
    func search(attributes: [ReferenceAttribute]) async throws -> [ArchiveCandidate]
}
struct DemoArchiveAdapter: ArchiveAdapter {
    var label: String { "LOCAL DEMO · synthetic archive" }
    func search(attributes: [ReferenceAttribute]) async throws -> [ArchiveCandidate] {
        guard let url = Bundle.main.url(forResource: "archive", withExtension: "json") else { throw ReferenceError.message("Demo archive resource is missing.") }
        let assets = try JSONDecoder().decode([DemoAsset].self, from: Data(contentsOf: url))
        return ReferenceMatching.demoMatches(attributes, assets: assets)
    }
}
enum ReferenceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}
