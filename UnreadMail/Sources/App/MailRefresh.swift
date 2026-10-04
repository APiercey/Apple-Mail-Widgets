import Foundation
import Darwin

/// Shared by the UI and the launchd job. The lock prevents overlapping collectors.
enum MailRefresh {
    static func collect(at path: URL = SnapshotStore.url,
                        read: () throws -> ReaderResult = MailReader.read) throws -> MailSnapshot? {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let lock = open(path.deletingLastPathComponent().appendingPathComponent("refresh.lock").path,
                        O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw POSIXError(.EIO) }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK { return nil }
            throw POSIXError(.EIO)
        }
        defer { flock(lock, LOCK_UN) }
        var next = SnapshotStore.load(from: path)
        do {
            let value = try read()
            next.status = value.status
            next.detail = value.detail
            if value.status == "ready" || value.status == "partial" {
                if let discovered = value.inboxes, !discovered.isEmpty {
                    let previous = next.inboxes ?? []
                    let previousUpdatedAt = next.updatedAt
                    next.inboxes = discovered.map { inbox in
                        guard inbox.readError != nil,
                              var cached = previous.first(where: { $0.id == inbox.id }) else { return inbox }
                        cached.name = inbox.name
                        cached.readError = inbox.readError
                        if cached.updatedAt == nil { cached.updatedAt = previousUpdatedAt }
                        return cached
                    }
                    next.messages = MailSnapshot.newest(next.inboxes!.flatMap(\.unreadMessages))
                    next.unreadCount = next.inboxes!.reduce(0) { $0 + $1.unreadCount }
                    if discovered.contains(where: { $0.readError == nil }) { next.updatedAt = .now }
                } else {
                    next.inboxes = value.inboxes
                    next.messages = value.messages ?? []
                    next.unreadCount = value.unreadCount ?? 0
                    next.updatedAt = .now
                }
            }
        } catch {
            next.status = "error"
            next.detail = error.localizedDescription
        }
        try SnapshotStore.save(next, to: path)
        return next.newestTen()
    }
}
