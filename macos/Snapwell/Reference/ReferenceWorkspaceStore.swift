import Foundation
import CryptoKit
import Darwin

struct ReferenceConfiguration: Codable, Equatable, Sendable {
    var connection = "demo"
    var endpoint = ""
    var provider: AIProvider = .ollama
    var model = "gemma3:4b"
    var visualRanking = true
}
struct ReferenceWorkspaceSnapshot: Codable {
    var schema = 1
    var revision = UUID().uuidString
    var activeID: String
    var briefs: [ReferenceBrief]
    var configuration: ReferenceConfiguration
}
/// Atomic writes, validated backups, optimistic concurrency and explicit recovery.
/// No credentials are part of this format. Legacy briefs.json is retained as migration evidence.
@MainActor final class ReferenceWorkspaceStore {
    let root: URL
    private var digest: String?
    var readOnly = false
    var recoveryAvailable: Bool { FileManager.default.fileExists(atPath: backup.path) }
    private var file: URL { root.appendingPathComponent("workspace.json") }
    private var backup: URL { root.appendingPathComponent("workspace.backup.json") }
    init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    func load() throws -> ReferenceWorkspaceSnapshot? {
        if FileManager.default.fileExists(atPath: file.path) {
            let bytes = try Data(contentsOf: file); digest = Self.hash(bytes)
            do { return try decode(bytes) } catch { readOnly = true; throw error }
        }
        let legacy = root.appendingPathComponent("briefs.json")
        if FileManager.default.fileExists(atPath: legacy.path) {
            do {
                let briefs = try JSONDecoder().decode([ReferenceBrief].self, from: Data(contentsOf: legacy))
                guard !briefs.isEmpty else { throw ReferenceError.message("The legacy brief file is empty.") }
                return ReferenceWorkspaceSnapshot(activeID: briefs[0].id, briefs: briefs, configuration: ReferenceConfiguration())
            } catch { readOnly = true; throw error }
        }
        return nil
    }
    private func decode(_ data: Data) throws -> ReferenceWorkspaceSnapshot {
        let value = try JSONDecoder().decode(ReferenceWorkspaceSnapshot.self, from: data)
        guard value.schema == 1, !value.briefs.isEmpty, Set(value.briefs.map(\.id)).count == value.briefs.count,
              value.briefs.allSatisfy({ Set($0.references.map(\.mediaID)).count == $0.references.count }) else {
            throw ReferenceError.message("Workspace format is unsupported or has duplicate identities. Files were preserved.")
        }
        return value
    }
    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        let descriptor = open(root.appendingPathComponent(".workspace.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw ReferenceError.message("Workspace lock could not be opened.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw ReferenceError.message("Another process is saving this workspace. Try again.") }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
    func save(_ value: ReferenceWorkspaceSnapshot) throws {
        guard !readOnly else { throw ReferenceError.message("Workspace is read-only until recovery. No changes have been saved.") }
        try withLock {
            let old = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
            guard old.map(Self.hash) == digest else {
                readOnly = true
                throw ReferenceError.message("Another app changed this workspace. Reopen it to load the latest changes; stale data was not written.")
            }
            if let old { _ = try decode(old); try old.write(to: backup, options: .atomic); try protect(backup) }
            var next = value; next.revision = UUID().uuidString
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let bytes = try encoder.encode(next); _ = try decode(bytes)
            try bytes.write(to: file, options: .atomic); try protect(file); digest = Self.hash(bytes)
        }
    }
    func restoreBackup() throws -> ReferenceWorkspaceSnapshot {
        try withLock {
            let bytes = try Data(contentsOf: backup); let value = try decode(bytes)
            if FileManager.default.fileExists(atPath: file.path) {
                let preserved = root.appendingPathComponent("preserved-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: file, to: preserved); try protect(preserved)
            }
            try bytes.write(to: file, options: .atomic); try protect(file)
            digest = Self.hash(bytes); readOnly = false; return value
        }
    }
    private func protect(_ file: URL) throws { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
