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
    var visualDistance: Double?
    var semanticScore: Double?
    var startSeconds: Double?
    var endSeconds: Double?
    var availability: String?
    var observedAt: String?
    var coverage: String?
    var installation: String?
    var query: String?
    var resultKind: String?
    var sourceAssetID: String?
    var connectionOrigin: String?
}
struct ReferenceEntry: Codable, Equatable, Sendable {
    var mediaID: String
    var attributes = ReferenceAttribute.empty
    var analysisOrigin = "Not analyzed — enter observations manually or configure a provider."
    var candidates: [ArchiveCandidate] = []
    var selectedIDs: Set<String> = []
    var searchOrigin: String?
    var selections: [ArchiveCandidate]?
    var searchCoverage: String?
}
struct ReferenceBrief: Codable, Identifiable, Equatable, Sendable {
    var id = UUID().uuidString
    var title = "Untitled brief"
    var notes = ""
    var references: [ReferenceEntry] = []
    var removedReferences: [ReferenceEntry]?
}
struct ReferenceManifest: Codable, Sendable {
    var format = "vaultline-reference-package/v2"
    var exportedAt = Date()
    var brief: ReferenceBrief
    var references: [String: String]
    var checksums: [String: String]?
    var scope = "Reference media and evidence-backed select identifiers; archive originals are not included. Demo selects are synthetic."
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
    func allCandidates() throws -> [ArchiveCandidate] {
        guard let url = Bundle.main.url(forResource: "archive", withExtension: "json") else { throw ReferenceError.message("Demo archive resource is missing.") }
        let assets = try JSONDecoder().decode([DemoAsset].self, from: Data(contentsOf: url))
        return assets.map { ArchiveCandidate(id: $0.id, name: $0.name, source: $0.source, thumbnail: $0.thumbnail, timecode: $0.timecode, evidence: ["Synthetic catalog candidate for overall visual comparison."], demo: true) }
    }
    func search(attributes: [ReferenceAttribute]) async throws -> [ArchiveCandidate] {
        guard let url = Bundle.main.url(forResource: "archive", withExtension: "json") else { throw ReferenceError.message("Demo resource missing.") }
        return ReferenceMatching.demoMatches(attributes, assets: try JSONDecoder().decode([DemoAsset].self, from: Data(contentsOf: url)))
    }
}
enum ReferenceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}
