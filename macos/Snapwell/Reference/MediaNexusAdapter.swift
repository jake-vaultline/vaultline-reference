import Foundation

/// Real Core contract: POST /api/mcp/v1/rpc, tools/call search_assets.
/// Reads only; export is the supported handoff instead of inventing a collection write API.
struct MediaNexusAdapter: ArchiveAdapter {
    var endpoint: URL
    var token: String
    var session: URLSession = .shared
    var label: String { "MEDIA NEXUS · \(endpoint.host ?? "configured server")" }
    func search(attributes: [ReferenceAttribute]) async throws -> [ArchiveCandidate] {
        let terms = ReferenceMatching.tokens(attributes)
        guard !terms.isEmpty else { throw ReferenceError.message("Choose at least one attribute with searchable words.") }
        // Core accepts at most six AND terms. Be explicit about this bound in the UI.
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": UUID().uuidString, "method": "tools/call",
            "params": ["name": "search_assets", "arguments": ["terms": terms.prefix(6).joined(separator: " "), "mediaType": "video"]]
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ReferenceError.message("Media Nexus refused the request (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)). Check connection and read scope; demo was not substituted.")
        }
        return try Self.decode(data)
    }
    func visual(assetID: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": UUID().uuidString, "method": "tools/call",
            "params": ["name": "get_asset_visual", "arguments": ["assetId": assetID]]
        ])
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let rpc = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = rpc["result"] as? [String: Any],
              let structured = result["structuredContent"] as? [String: Any], structured["assetId"] as? String == assetID,
              let blocks = result["content"] as? [[String: Any]],
              let image = blocks.first(where: { $0["type"] as? String == "image" }),
              let mime = image["mimeType"] as? String, ["image/jpeg", "image/png", "image/webp"].contains(mime),
              let base64 = image["data"] as? String, base64.count < 7_000_000,
              let decoded = Data(base64Encoded: base64) else {
            throw ReferenceError.message("Managed thumbnail unavailable for this asset.")
        }
        return decoded
    }
    static func decode(_ data: Data) throws -> [ArchiveCandidate] {
        guard let rpc = try JSONSerialization.jsonObject(with: data) as? [String: Any], rpc["error"] == nil,
              let result = rpc["result"] as? [String: Any], (result["isError"] as? Bool) != true,
              let envelope = result["structuredContent"] as? [String: Any],
              envelope["authority"] as? String == "media-nexus",
              let payload = envelope["data"] as? [String: Any], let items = payload["items"] as? [[String: Any]] else {
            throw ReferenceError.message("Media Nexus returned an error or unsupported contract. No results were fabricated.")
        }
        let evidence = payload["evidence"] as? [[String: Any]] ?? []
        return try items.map { item in
            guard let id = item["assetId"] as? String, let name = item["name"] as? String,
                  let matches = item["matched"] as? [String] else { throw ReferenceError.message("Incomplete archive search result.") }
            let ev = evidence.first { ($0["id"] as? String) == id }
            // search_assets provides metadata matches, not shot timecodes. Leave them unknown.
            return ArchiveCandidate(id: id, name: name, source: item["folder"] as? String ?? "Archive location unknown",
                                    thumbnail: ev?["thumbnail"] as? String, timecode: nil,
                                    evidence: matches.isEmpty ? ["Server returned this asset without a match explanation."] : matches,
                                    demo: false)
        }
    }
}
