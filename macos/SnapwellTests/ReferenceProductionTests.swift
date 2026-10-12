import Foundation
import AppKit
import Testing
@testable import Snapwell

@Suite("Reference production reliability", .serialized)
struct ReferenceProductionTests {
    @Test("Legacy brief migration retains the original file and stable identities")
    @MainActor func migration() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        var brief = ReferenceBrief(); brief.title = "Existing brief"; brief.references = [ReferenceEntry(mediaID: "existing-ref")]
        let bytes = try JSONEncoder().encode([brief]); try bytes.write(to: root.appendingPathComponent("briefs.json"))
        let service = ReferenceService(root: root); service.persist()
        #expect(service.briefs[0].id == brief.id)
        #expect(try Data(contentsOf: root.appendingPathComponent("briefs.json")) == bytes)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("workspace.json").path))
    }
    @Test("Configuration survives reopening while connection credentials remain absent from disk")
    @MainActor func configPersistence() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let service = ReferenceService(root: root); service.provider = .ollama; service.model = "installed-vision-model"
        service.endpoint = "https://example.invalid/api/mcp/v1/rpc"; service.connection = "real"; service.token = "TEST_SECRET_DO_NOT_PERSIST"; service.persist()
        let loaded = ReferenceService(root: root)
        #expect(loaded.model == "installed-vision-model"); #expect(loaded.endpoint == service.endpoint)
        #expect(loaded.connection == "real"); #expect(loaded.token.isEmpty)
        let text = try String(contentsOf: root.appendingPathComponent("workspace.json"), encoding: .utf8)
        #expect(!text.contains("TEST_SECRET_DO_NOT_PERSIST"))
        service.endpoint = "https://user:password@example.invalid/api/mcp/v1/rpc?token=secret"; service.persist()
        let invalid = try String(contentsOf: root.appendingPathComponent("workspace.json"), encoding: .utf8)
        #expect(!invalid.contains("password")); #expect(!invalid.contains("token=secret"))
    }
    @Test("A corrupt analysis cache cannot disable a valid workspace")
    @MainActor func cacheCorruption() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("bad cache".utf8).write(to: root.appendingPathComponent("analysis-cache.json"))
        let service = ReferenceService(root: root); service.persist()
        #expect(service.writable)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("workspace.json").path))
    }
    @Test("Corrupt workspace is read-only and explicit backup recovery preserves damaged bytes")
    @MainActor func backupRecovery() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let service = ReferenceService(root: root); service.briefs[0].title = "Known good"; service.persist()
        service.briefs[0].title = "Latest"; service.persist()
        let damaged = Data("corrupt workspace bytes".utf8); try damaged.write(to: root.appendingPathComponent("workspace.json"))
        let reopened = ReferenceService(root: root); #expect(!reopened.writable); #expect(reopened.recoveryAvailable)
        reopened.persist(); #expect(try Data(contentsOf: root.appendingPathComponent("workspace.json")) == damaged)
        reopened.restoreBackup(); #expect(reopened.writable); #expect(reopened.briefs[0].title == "Known good")
        let preserved = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("preserved-") }
        #expect(preserved.count == 1); #expect(try Data(contentsOf: preserved[0]) == damaged)
    }
    @Test("Two writers cannot overwrite newer data with a stale snapshot")
    @MainActor func concurrentSave() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let first = ReferenceService(root: root); first.persist(); let second = ReferenceService(root: root)
        first.briefs[0].title = "New truth"; first.persist()
        second.briefs[0].title = "Stale truth"; second.persist()
        #expect(!second.writable)
        #expect(ReferenceService(root: root).briefs[0].title == "New truth")
    }
    @Test("New searches retain immutable selections and their original evidence")
    @MainActor func durableSelections() async throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let service = ReferenceService(root: root); service.addReference("reference")
        service.briefs[0].references[0].attributes[0].value = "coast"
        await service.search(referenceID: "reference")
        let selected = try #require(service.briefs[0].references[0].candidates.first)
        service.toggleSelection(selected, referenceID: "reference")
        service.briefs[0].references[0].attributes[0].value = "city"
        await service.search(referenceID: "reference")
        #expect(service.briefs[0].references[0].selectedIDs.contains(selected.id))
        #expect(service.briefs[0].references[0].selections?.first == selected)
        let loaded = ReferenceService(root: root); #expect(loaded.briefs[0].references[0].selections?.first == selected)
    }
    @Test("Removing a missing reference is reversible and retains selection evidence")
    @MainActor func removableReferences() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let service = ReferenceService(root: root); service.addReference("missing")
        let candidate = ArchiveCandidate(id: "selected", name: "Selected", source: "Synthetic", evidence: ["Stored evidence"], demo: true)
        service.toggleSelection(candidate, referenceID: "missing")
        service.removeReference("missing")
        #expect(service.briefs[0].references.isEmpty)
        let loaded = ReferenceService(root: root); loaded.restoreReference("missing")
        #expect(loaded.briefs[0].references[0].selectedIDs == ["selected"])
        #expect(loaded.briefs[0].references[0].selections?.first?.evidence == ["Stored evidence"])
    }
    @Test("Shot ranges are supplied, validated, and bound to the real asset identity")
    func groundedRanges() throws {
        let value: [String: Any] = ["installation": "test-installation", "coverage": "Synthetic verified shots", "as_of": "2026-10-12T00:00:00Z", "data": ["items": [
            ["assetId": "asset-a", "name": "a.mov", "kind": "visualShot", "start": 1.25, "end": 4.5, "explanation": "Verified indexed shot"],
            ["assetId": "asset-b", "name": "b.mov", "kind": "visualShot", "start": -2.0, "end": 5.0],
            ["assetId": "asset-c", "name": "c.mov", "kind": "asset"]]]]
        let candidates = try MediaNexusAdapter.decodeEnvelope(value, query: "warm light")
        #expect(candidates[0].assetID == "asset-a"); #expect(candidates[0].id.contains("test-installation"))
        #expect(candidates[0].startSeconds == 1.25); #expect(candidates[0].endSeconds == 4.5)
        #expect(candidates[0].timecode?.contains("Asset seconds") == true)
        #expect(candidates[1].timecode == nil); #expect(candidates[2].timecode == nil)
        #expect(candidates[0].evidence == ["Verified indexed shot"])
    }
    @Test("An unavailable or stale empty index is not reported as no footage")
    func coverageFailures() {
        let unavailable: [String: Any] = ["data": ["items": [], "summary": "Index unavailable", "suggestions": [["title": "Restore index"]]]]
        #expect(throws: (any Error).self) { try MediaNexusAdapter.decodeEnvelope(unavailable, query: "coast") }
        let stale: [String: Any] = ["freshness": ["verdict": "stale", "reason": "Storage unobserved"], "data": ["items": []]]
        #expect(throws: (any Error).self) { try MediaNexusAdapter.decodeEnvelope(stale, query: "coast") }
    }
    @Test("Untrusted endpoint URLs cannot carry credentials or redirects in configuration")
    func originSafety() {
        for endpoint in ["http://example.com/api/mcp/v1/rpc", "https://user:pass@example.com/api/mcp/v1/rpc", "https://example.com/api/mcp/v1/rpc?key=value", "https://example.com/api/mcp/v1/rpc#fragment", "file:///api/mcp/v1/rpc"] {
            #expect(throws: (any Error).self) { try MediaNexusAdapter.validateEndpoint(endpoint) }
        }
    }
    @Test("Native image comparison distinguishes the same preview from another scene")
    func visualDistance() async throws {
        let coast = try Data(contentsOf: #require(Bundle.main.url(forResource: "warm-coast", withExtension: "png")))
        let city = try Data(contentsOf: #require(Bundle.main.url(forResource: "blue-city", withExtension: "png")))
        let matcher = ReferenceVisualMatcher()
        let same = try await matcher.distance(reference: coast, candidate: coast)
        let other = try await matcher.distance(reference: coast, candidate: city)
        #expect(same < 0.00001); #expect(other > same)
        #expect(try await matcher.distance(reference: coast, candidate: city) == other)
    }
    @Test("An export failure after copying one reference leaves no partial package")
    func exportFailureCleanup() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let good = root.appendingPathComponent("good.png"); try Data("test media bytes".utf8).write(to: good)
        let sources = [ReferenceExportSource(id: "a", filename: "a.png", url: good), ReferenceExportSource(id: "b", filename: "b.mp4", url: root.appendingPathComponent("missing"))]
        #expect(throws: (any Error).self) { try ReferenceExporter.export(brief: ReferenceBrief(), sources: sources, directory: root) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.contains("Vaultline-Reference") })
    }
    @Test("A cancelled export cleans its staging directory")
    func cancelledExport() async throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.png"); try Data("test bytes".utf8).write(to: source)
        let task = Task {
            await Task.yield()
            return try ReferenceExporter.export(brief: ReferenceBrief(), sources: [ReferenceExportSource(id: "ref", filename: "ref.png", url: source)], directory: root)
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled export completed") } catch is CancellationError {} catch { Issue.record("Unexpected export failure") }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.contains("Vaultline-Reference") })
    }
}
