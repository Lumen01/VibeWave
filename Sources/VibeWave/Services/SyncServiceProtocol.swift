import Foundation

public protocol SyncServiceProtocol {
    func syncDirectory(at url: URL, toolId: String) async throws -> SyncProgress
    func syncFile(at url: URL, toolId: String) async throws -> (Int, Set<String>, String)
    func syncFiles(at urls: [URL], toolId: String) async throws -> (Int, Set<String>, String)
}
