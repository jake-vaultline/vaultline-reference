import AppKit
import Foundation
import SwiftData
import Testing
@testable import Snapwell

@Suite("Vaultline Reference workflow", .serialized)
struct ReferenceWorkflowTests {
    @Test("Only chosen attributes influence matches; explanation quotes actual fixture fields")
    func evidenceGrounding() {
        let assets = [DemoAsset(id: "a", name: "A", source: "synthetic", thumbnail: "a", metadata: ["subject": "coast ocean", "lighting": "warm sunset"]), DemoAsset(id: "b", name: "B", source: "synthetic", thumbnail: "b", metadata: ["subject": "city"])]
        var attributes = ReferenceAttribute.empty
        attributes[0].value = "coast"; attributes[3].value = "city"; attributes[3].matters = false
        let matches = ReferenceMatching.demoMatches(attributes, assets: assets)
        #expect(matches.map(\.id) == ["a"])
        #expect(matches[0].evidence == ["Fixture subject: coast ocean (matches coast)."])
        #expect(matches[0].timecode == nil)
        attributes[0].matters = false
        #expect(ReferenceMatching.demoMatches(attributes, assets: assets).isEmpty)
    }
    @Test("Real contract preserves metadata evidence and unknown timecodes")
    func actualMCPContract() throws {
        let data = Data(#"{"jsonrpc":"2.0","id":"1","result":{"isError":false,"structuredContent":{"authority":"media-nexus","data":{"items":[{"assetId":"a","name":"A.mov","folder":"Shoot","matched":["tagged ‘coast’"]}],"evidence":[{"id":"a","thumbnail":"/thumb/a"}]}}}}"#.utf8)
        let result = try MediaNexusAdapter.decode(data)
        #expect(result.count == 1)
        #expect(!result[0].demo)
        #expect(result[0].timecode == nil)
        #expect(result[0].evidence == ["tagged ‘coast’"])
        #expect(result[0].thumbnail == "/thumb/a")
    }
    @Test("Real adapter sends the semantic MCP request without silently dropping chosen words")
    func realTransportContract() async throws {
        ReferenceMockProtocol.response = Data(#"{"jsonrpc":"2.0","id":"1","result":{"isError":false,"structuredContent":{"authority":"media-nexus","contract":"mediaNexus.intelligence/1","data":{"items":[],"evidence":[]}}}}"#.utf8)
        ReferenceMockProtocol.capture = { request in
            #expect(request.url?.path == "/api/mcp/v1/rpc")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token")
            var data = request.httpBody
            if data == nil, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var bytes = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }; bytes.append(contentsOf: buffer.prefix(count))
                }
                data = bytes
            }
            let body = try #require(data)
            let rpc = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(rpc["method"] as? String == "tools/call")
            let params = try #require(rpc["params"] as? [String: Any]); #expect(params["name"] as? String == "query_archive")
            let args = try #require(params["arguments"] as? [String: Any])
            #expect(args["mediaType"] as? String == "video")
            #expect(args["query"] as? String == "subject: beach coast ocean warm teal orange wide")
            #expect(args["limit"] as? Int == 30)
        }
        defer { ReferenceMockProtocol.capture = nil }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ReferenceMockProtocol.self]
        let adapter = MediaNexusAdapter(endpoint: URL(string: "https://example.invalid/api/mcp/v1/rpc")!, token: "synthetic-test-token", session: URLSession(configuration: config))
        var attributes = ReferenceAttribute.empty; attributes[0].value = "beach coast ocean warm teal orange wide"
        #expect(try await adapter.search(attributes: attributes).isEmpty)
    }
    @Test("Malformed and failed MCP responses never become demo results")
    func invalidMCP() {
        for text in [#"{"error":{"code":-32603}}"#, #"{"result":{"isError":true}}"#, #"{"result":{"structuredContent":{"authority":"other","data":{"items":[]}}}}"#] {
            #expect(throws: (any Error).self) { try MediaNexusAdapter.decode(Data(text.utf8)) }
        }
    }
    @Test("Unstructured model prose is rejected, subjective mood is explicit")
    @MainActor func analysisValidation() throws {
        #expect(throws: (any Error).self) { try ReferenceService.decodeAttributes("Looks like a beach") }
        let values = Dictionary(uniqueKeysWithValues: ReferenceAttribute.empty.map { ($0.id, $0.id == "subject" ? "coast" : "") })
        let result = try ReferenceService.decodeAttributes(String(decoding: JSONEncoder().encode(values), as: UTF8.self))
        #expect(result[0].value == "coast")
        #expect(result.filter(\.interpretation).map(\.id) == ["mood"])
    }
    @Test("Image and video import, corrected brief, selects, persistence and portable export")
    @MainActor func completeWorkflow() async throws {
        let root = try IntegrationTestSupport.makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = MediaStorageService(baseURL: root)
        let container = try TestContainer.create(); let context = ModelContext(container)
        let importer = ImportService(storage: storage, sidecarService: MetadataSidecarService(storage: storage))
        let appBundle = Bundle(for: NSClassFromString("Snapwell.MediaItem") ?? NSObject.self)
        // Xcode host is the app; Bundle.main contains deterministic fixtures.
        let image = try #require(Bundle.main.url(forResource: "warm-coast", withExtension: "png") ?? appBundle.url(forResource: "warm-coast", withExtension: "png"))
        let video = try #require(Bundle.main.url(forResource: "warm-coast", withExtension: "mp4") ?? appBundle.url(forResource: "warm-coast", withExtension: "mp4"))
        try await importer.importSingleFile(image, into: context, spaceId: nil, analyze: false)
        try await importer.importSingleFile(video, into: context, spaceId: nil, analyze: false)
        let items = try context.fetch(FetchDescriptor<MediaItem>())
        #expect(items.count == 2)
        #expect(items.contains { $0.isVideo && ($0.duration ?? 0) >= 2.9 })
        #expect(items.allSatisfy { $0.analysisResult == nil })
        let workspace = root.appendingPathComponent("workspace")
        let service = ReferenceService(root: workspace, storage: storage)
        service.briefs[0].title = "Coastal launch film"
        for item in items { service.addReference(item.id) }
        for j in service.briefs[0].references.indices {
            service.briefs[0].references[j].attributes[0].value = "coast"
            service.briefs[0].references[j].attributes[3].value = "warm"
            await service.search(referenceID: service.briefs[0].references[j].mediaID)
            let candidate = try #require(service.briefs[0].references[j].candidates.first)
            #expect(candidate.demo)
            #expect(candidate.id == "demo-coast-001")
            service.briefs[0].references[j].selectedIDs.insert(candidate.id)
        }
        service.persist()
        let loaded = ReferenceService(root: workspace, storage: storage)
        #expect(loaded.briefs == service.briefs)
        let package = try service.export(to: root, items: items)
        let encoder = JSONDecoder(); encoder.dateDecodingStrategy = .iso8601
        let manifest = try encoder.decode(ReferenceManifest.self, from: Data(contentsOf: package.appendingPathComponent("manifest.json")))
        #expect(manifest.references.count == 2)
        #expect(manifest.brief.references.allSatisfy { $0.candidates.count == 1 && $0.candidates[0].id == "demo-coast-001" })
        for item in items {
            let relative = try #require(manifest.references[item.id])
            #expect(try Data(contentsOf: package.appendingPathComponent(relative)) == Data(contentsOf: storage.mediaURL(filename: item.filename)))
        }
        #expect(FileManager.default.fileExists(atPath: package.appendingPathComponent("SELECTS.md").path))
    }
    @Test("Analysis cache prevents repeat provider calls and changes model identity")
    @MainActor func cachedAnalysis() async throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let storage = MediaStorageService(baseURL: root)
        let sample = try #require(Bundle.main.url(forResource: "warm-coast", withExtension: "png"))
        _ = try storage.copyMedia(from: sample, filename: "reference.png")
        let values = Dictionary(uniqueKeysWithValues: ReferenceAttribute.empty.map { ($0.id, $0.id == "subject" ? "coast" : "") })
        let context = String(decoding: try JSONEncoder().encode(values), as: UTF8.self)
        let content = String(decoding: try JSONSerialization.data(withJSONObject: ["imageContext": context, "imageSummary": "Coast", "patterns": []]), as: UTF8.self)
        let response = try JSONSerialization.data(withJSONObject: ["message": ["content": content]])
        ReferenceMockProtocol.response = response; ReferenceMockProtocol.resetCount()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ReferenceMockProtocol.self]
        let ai = AIAnalysisService(ollamaClient: OllamaClient(session: URLSession(configuration: config)))
        let workspace = root.appendingPathComponent("workspace")
        let service = ReferenceService(root: workspace, storage: storage, ai: ai)
        let item = MediaItem(id: "ref", mediaType: .image, filename: "reference.png", width: 960, height: 540)
        service.addReference(item.id)
        service.briefs[0].references[0].attributes[0].matters = false
        await service.analyze(item: item)
        #expect(!service.briefs[0].references[0].attributes[0].matters)
        #expect(service.briefs[0].references[0].attributes[0].value == "coast")
        await service.analyze(item: item)
        #expect(ReferenceMockProtocol.count == 1)
        #expect(service.briefs[0].references[0].analysisOrigin.hasPrefix("Cached"))
        let loaded = ReferenceService(root: workspace, storage: storage, ai: ai)
        await loaded.analyze(item: item)
        #expect(ReferenceMockProtocol.count == 1)
        loaded.model = "other-vision-model"
        await loaded.analyze(item: item)
        #expect(ReferenceMockProtocol.count == 2)
    }
    @Test("Video samples are analyzed separately, cached, and cannot assert camera movement")
    @MainActor func videoSampleAnalysis() async throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let storage = MediaStorageService(baseURL: root)
        let sample = try #require(Bundle.main.url(forResource: "warm-coast", withExtension: "mp4"))
        _ = try storage.copyMedia(from: sample, filename: "reference.mp4")
        var values = Dictionary(uniqueKeysWithValues: ReferenceAttribute.empty.map { ($0.id, $0.id == "subject" ? "coast" : "") })
        values["camera movement"] = "unproven pan"
        let context = String(decoding: try JSONEncoder().encode(values), as: UTF8.self)
        let content = String(decoding: try JSONSerialization.data(withJSONObject: ["imageContext": context, "imageSummary": "Coast", "patterns": []]), as: UTF8.self)
        ReferenceMockProtocol.response = try JSONSerialization.data(withJSONObject: ["message": ["content": content]])
        ReferenceMockProtocol.resetCount()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ReferenceMockProtocol.self]
        let ai = AIAnalysisService(ollamaClient: OllamaClient(session: URLSession(configuration: config)))
        let service = ReferenceService(root: root.appendingPathComponent("workspace"), storage: storage, ai: ai)
        let item = MediaItem(id: "video-ref", mediaType: .video, filename: "reference.mp4", width: 1920, height: 1080, duration: 3)
        service.addReference(item.id)
        await service.analyze(item: item)
        #expect(ReferenceMockProtocol.count == 2)
        #expect(service.briefs[0].references[0].analysisOrigin.contains("sampled frames"))
        #expect(service.briefs[0].references[0].attributes[5].value.isEmpty)
        #expect(service.briefs[0].references[0].attributes[0].value == "coast")
        await service.analyze(item: item)
        #expect(ReferenceMockProtocol.count == 2)
    }
    @Test("Corrupt workspace is preserved instead of overwritten")
    @MainActor func corruptionSafety() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("briefs.json"); try Data("broken".utf8).write(to: file)
        let service = ReferenceService(root: root); service.createBrief(); service.persist()
        #expect(try String(contentsOf: file, encoding: .utf8) == "broken")
        #expect(service.message.contains("could not load"))
    }
    @Test("Existing token required; HTTP credentials only allowed on loopback")
    @MainActor func connectionSafety() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let service = ReferenceService(root: root)
        service.connection = "real"; service.endpoint = "http://example.com/api/mcp/v1/rpc"; service.token = "synthetic-test-token"
        #expect(throws: (any Error).self) { try service.adapter() }
        service.endpoint = "http://127.0.0.1:8123/api/mcp/v1/rpc"
        #expect(service.token.isEmpty)
        service.token = "synthetic-test-token"
        #expect(try service.adapter().label.contains("MEDIA NEXUS"))
    }
}

private final class ReferenceMockProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response = Data()
    nonisolated(unsafe) static var capture: (@Sendable (URLRequest) throws -> Void)?
    nonisolated(unsafe) private static var calls = 0
    private static let lock = NSLock()
    static var count: Int { lock.withLock { calls } }
    static func resetCount() { lock.withLock { calls = 0 } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do { try Self.capture?(request) } catch { client?.urlProtocol(self, didFailWithError: error); return }
        Self.lock.withLock { Self.calls += 1 }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
