import Foundation
import Testing
@testable import Snapwell

@Suite("Reference import durability")
struct ReferenceImportReliabilityTests {
    @Test("A cancellable copy retains exact bytes and refuses to replace an existing file")
    func exactCopy() async throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let storage = MediaStorageService(baseURL: root), source = root.appendingPathComponent("source.bin")
        let data = Data(repeating: 0x5A, count: 2 * 1024 * 1024); try data.write(to: source)
        let destination = try await storage.copyMediaCancellable(from: source, filename: "copied.mp4")
        #expect(try Data(contentsOf: destination) == data)
        do { _ = try await storage.copyMediaCancellable(from: source, filename: "copied.mp4"); Issue.record("Copy overwrote an existing media file") } catch {}
        #expect(try Data(contentsOf: destination) == data)
        #expect(try FileManager.default.contentsOfDirectory(atPath: storage.mediaDir.path) == ["copied.mp4"])
    }
    @Test("Cancellation cannot publish a partial media file")
    func cancelledCopy() async throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let storage = MediaStorageService(baseURL: root), source = root.appendingPathComponent("source.bin")
        try Data(repeating: 0x2A, count: 8 * 1024 * 1024).write(to: source)
        let task = Task { await Task.yield(); return try await storage.copyMediaCancellable(from: source, filename: "cancelled.mp4") }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled copy completed") } catch is CancellationError {} catch { Issue.record("Unexpected copy error") }
        #expect(try FileManager.default.contentsOfDirectory(atPath: storage.mediaDir.path).isEmpty)
    }
    @Test("Changing archive origin clears a credential before another request can send it")
    @MainActor func scopedCredential() throws {
        let root = try IntegrationTestSupport.makeTempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let service = ReferenceService(root: root)
        service.endpoint = "https://first.invalid/api/mcp/v1/rpc"; service.token = "SYNTHETIC_FIRST_ORIGIN_TOKEN"
        service.endpoint = "https://second.invalid/api/mcp/v1/rpc"
        #expect(service.token.isEmpty)
        #expect(service.connectionStatus == "Not tested")
    }
}
