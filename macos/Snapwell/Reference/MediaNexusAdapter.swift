import Foundation

struct MediaNexusConnection: Sendable {
    var installation: String
    var freshness: String
    var coverage: String
    var tools: Set<String>
}
struct MediaNexusAdapter: ArchiveAdapter {
    var endpoint: URL
    var token: String
    var session: URLSession = .shared
    var label: String { "MEDIA NEXUS · \(endpoint.host ?? "configured server")" }
    static func validateEndpoint(_ text: String) throws -> URL {
        guard let url = URL(string: text), ["https", "http"].contains(url.scheme), url.path == "/api/mcp/v1/rpc",
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil, url.host != nil else {
            throw ReferenceError.message("Enter the exact Media Nexus /api/mcp/v1/rpc URL, without credentials or query parameters.")
        }
        guard url.scheme == "https" || ["localhost", "127.0.0.1", "::1", "[::1]"].contains(url.host) else {
            throw ReferenceError.message("Remote credentials require HTTPS; HTTP is supported only on loopback.")
        }
        return url
    }
    // Refuse redirects: a credential must never move to another origin.
    private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
    }
    func call(_ name: String, arguments: [String: Any]) async throws -> [String: Any] {
        _ = try Self.validateEndpoint(endpoint.absoluteString)
        guard !token.isEmpty else { throw ReferenceError.message("Connect with an existing read-scoped token first.") }
        try Task.checkCancellation()
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": UUID().uuidString, "method": "tools/call", "params": ["name": name, "arguments": arguments]])
        let (data, response) = try await session.data(for: request, delegate: NoRedirect())
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 8 * 1024 * 1024 else {
            throw ReferenceError.message("Media Nexus request failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)). Check access and connection. Demo data was not substituted.")
        }
        guard let rpc = try JSONSerialization.jsonObject(with: data) as? [String: Any], rpc["error"] == nil,
              let result = rpc["result"] as? [String: Any], (result["isError"] as? Bool) != true else {
            throw ReferenceError.message("Media Nexus could not answer \(name). Check the connection’s read scope and enabled modules.")
        }
        return result
    }
    private func envelope(_ result: [String: Any]) throws -> [String: Any] {
        guard let value = result["structuredContent"] as? [String: Any], value["authority"] as? String == "media-nexus",
              value["contract"] as? String == "mediaNexus.intelligence/1" else {
            throw ReferenceError.message("Media Nexus returned an unsupported contract. Results were withheld.")
        }
        return value
    }
    func capabilities() async throws -> MediaNexusConnection {
        let value = try envelope(await call("get_capabilities", arguments: [:]))
        let payload = value["data"] as? [String: Any] ?? [:], capabilities = payload["capabilities"] as? [String: Any] ?? [:]
        guard let installation = value["installation"] as? String, let tools = capabilities["tools"] as? [String] else { throw ReferenceError.message("The connection did not disclose its installation or tools.") }
        let fresh = value["freshness"] as? [String: Any] ?? [:]
        return MediaNexusConnection(installation: installation, freshness: fresh["verdict"] as? String ?? "unknown", coverage: value["coverage"] as? String ?? "Coverage unavailable", tools: Set(tools))
    }
    func search(attributes: [ReferenceAttribute]) async throws -> [ArchiveCandidate] { try await searchPage(attributes: attributes).candidates }
    func searchPage(attributes: [ReferenceAttribute]) async throws -> MediaNexusSearchPage {
        let selected = attributes.filter { $0.matters && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !selected.isEmpty else { throw ReferenceError.message("Choose at least one reference attribute.") }
        let query = selected.map { "\($0.id): \($0.value)" }.joined(separator: "; ")
        let result = try await call("query_archive", arguments: ["query": String(query.prefix(500)), "mediaType": "video", "limit": 30])
        let value = try envelope(result)
        let candidates = try Self.decodeEnvelope(value, query: query).map { var candidate = $0; candidate.connectionOrigin = endpoint.absoluteString; return candidate }
        return MediaNexusSearchPage(candidates: candidates, coverage: (value["coverage"] as? String ?? "Coverage unavailable") + " Freshness: \((value["freshness"] as? [String: Any])?["verdict"] as? String ?? "unknown").")
    }
    /// Browse a bounded recent pool to permit visual discovery without any metadata description.
    func recentCandidates() async throws -> [ArchiveCandidate] {
        let value = try envelope(await call("rank_assets", arguments: ["metric": "recent", "mediaType": "video", "limit": 30]))
        return try Self.decodeEnvelope(value, query: "Recent video candidates for on-device visual comparison").map { var candidate = $0; candidate.connectionOrigin = endpoint.absoluteString; return candidate }
    }
    func visual(assetID: String) async throws -> Data {
        let result = try await call("get_asset_visual", arguments: ["assetId": assetID])
        guard let structured = result["structuredContent"] as? [String: Any], structured["assetId"] as? String == assetID,
              let blocks = result["content"] as? [[String: Any]], let image = blocks.first(where: { $0["type"] as? String == "image" }),
              let mime = image["mimeType"] as? String, ["image/jpeg", "image/png", "image/webp"].contains(mime),
              let base64 = image["data"] as? String, base64.count <= 7_000_000, let decoded = Data(base64Encoded: base64) else {
            throw ReferenceError.message("Managed thumbnail unavailable for this asset.")
        }
        return decoded
    }
    func availability(assetID: String) async throws -> String {
        let value = try envelope(await call("asset_details", arguments: ["assetId": assetID]))
        let items = (value["data"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
        guard let item = items.first, item["assetId"] as? String == assetID else { return "Availability unknown" }
        if item["orphaned"] as? Bool == true { return "Orphaned asset — source unavailable" }
        if item["volumeOnline"] as? Bool == true { return "Source volume online · proxy \(item["proxyStatus"] as? String ?? "unknown")" }
        return "Source volume offline or untracked · preview may remain available"
    }
    static func decode(_ data: Data) throws -> [ArchiveCandidate] {
        guard let rpc = try JSONSerialization.jsonObject(with: data) as? [String: Any], rpc["error"] == nil,
              let result = rpc["result"] as? [String: Any], result["isError"] as? Bool != true,
              let value = result["structuredContent"] as? [String: Any], value["authority"] as? String == "media-nexus" else { throw ReferenceError.message("Invalid archive response.") }
        return try decodeEnvelope(value, query: "Legacy metadata search")
    }
    static func decodeEnvelope(_ value: [String: Any], query: String) throws -> [ArchiveCandidate] {
        guard let payload = value["data"] as? [String: Any], let items = payload["items"] as? [[String: Any]] else { throw ReferenceError.message("Archive result is incomplete.") }
        let ev = payload["evidence"] as? [[String: Any]] ?? []
        let fresh = value["freshness"] as? [String: Any] ?? [:]
        // Empty results with recovery suggestions represent an unavailable index, not absence.
        if items.isEmpty, let suggestions = payload["suggestions"] as? [Any], !suggestions.isEmpty {
            throw ReferenceError.message("\(payload["summary"] as? String ?? "Archive search is unavailable.") \(value["coverage"] as? String ?? "")")
        }
        if items.isEmpty, fresh["verdict"] as? String != "current", !fresh.isEmpty {
            throw ReferenceError.message("No candidates were returned, but archive freshness is \(fresh["verdict"] as? String ?? "unknown"). \(fresh["reason"] as? String ?? "Storage observation is unavailable.")")
        }
        return try items.compactMap { item in
            if item["kind"] as? String == "dateFolder" { return nil }
            guard let id = item["assetId"] as? String, let name = item["name"] as? String else { throw ReferenceError.message("Incomplete asset identity.") }
            let kind = item["kind"] as? String ?? "asset"
            let start = (kind == "mixedMomentAndShot" ? item["shotStart"] : item["start"]) as? Double
            let end = (kind == "mixedMomentAndShot" ? item["shotEnd"] : item["end"]) as? Double
            let validRange = start.map { $0.isFinite && $0 >= 0 } == true && end.map { $0.isFinite && $0 > (start ?? .infinity) } == true
            let explanation = item["explanation"] as? String
            let matches = item["matched"] as? [String] ?? explanation.map { [$0] } ?? ["Catalog candidate; visual relevance still needs comparison."]
            var candidate = ArchiveCandidate(id: ((value["installation"] as? String).map { $0 + "|" } ?? "") + id + (validRange ? "@\(start!)-\(end!)" : ""), name: name, source: item["folder"] as? String ?? "Archive location unknown",
                                             thumbnail: ev.first { $0["id"] as? String == id }?["thumbnail"] as? String,
                                             timecode: validRange ? String(format: "Asset seconds %.3f–%.3f · server-supplied %@", start!, end!, kind) : nil, evidence: matches, demo: false)
            candidate.sourceAssetID = id
            let score = item["score"] as? Double
            candidate.semanticScore = score?.isFinite == true ? score : nil
            candidate.startSeconds = validRange ? start : nil; candidate.endSeconds = validRange ? end : nil
            candidate.observedAt = value["as_of"] as? String
            candidate.coverage = (value["coverage"] as? String ?? "Coverage unavailable") + " Freshness: \(fresh["verdict"] as? String ?? "unknown"); \(fresh["reason"] as? String ?? "observation unavailable")."
            candidate.installation = value["installation"] as? String; candidate.query = query; candidate.resultKind = kind
            return candidate
        }
    }
}
extension ArchiveCandidate {
    var assetID: String { sourceAssetID ?? id }
}

struct MediaNexusSearchPage: Sendable {
    var candidates: [ArchiveCandidate]
    var coverage: String
}
