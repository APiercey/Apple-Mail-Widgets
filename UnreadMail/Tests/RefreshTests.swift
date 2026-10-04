import Foundation
import Darwin

@main struct RefreshTests {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("snapshot.json")
        let item = MailItem(id: 1, sender: "Example", subject: "Test", receivedAt: .now, messageID: "test")
        let success = try MailRefresh.collect(at: path) {
            ReaderResult(inboxes: [], messages: [item], unreadCount: 7, status: "ready", detail: "")
        }!
        check(success.updatedAt != nil && success.unreadCount == 7, "Successful collection updates data and timestamp")
        let failed = try MailRefresh.collect(at: path) {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey:"Temporary failure"])
        }!
        check(failed.messages == success.messages && failed.updatedAt == success.updatedAt, "Failure retains last successful data")
        check(failed.status == "error", "Failure remains visible")
        let closed = try MailRefresh.collect(at: path) {
            ReaderResult(status: "mailClosed", detail: "Open Mail")
        }!
        check(closed.status == "mailClosed" && closed.updatedAt == success.updatedAt, "Mail-closed state retains data")
        let fd = open(folder.appendingPathComponent("refresh.lock").path, O_RDWR)
        check(fd >= 0 && flock(fd, LOCK_EX | LOCK_NB) == 0, "Test lock acquired")
        var called = false
        let skipped = try MailRefresh.collect(at: path) {
            called = true
            return ReaderResult(status:"ready",detail:"")
        }
        check(skipped == nil && !called, "Overlapping collectors must not read or write")
        flock(fd, LOCK_UN); close(fd)
        let recovered = try MailRefresh.collect(at: path) {
            ReaderResult(inboxes: [], messages: [], unreadCount: 0, status: "ready", detail: "")
        }
        check(recovered?.status == "ready", "The lock is released between runs")
        let checked = Date(timeIntervalSince1970: 1000)
        let work = InboxSnapshot(id: "work", name: "Work", unreadCount: 7,
                                 unreadMessages: [item], recentMessages: [item], updatedAt: checked)
        _ = try MailRefresh.collect(at: path) {
            ReaderResult(inboxes: [work], status: "ready", detail: "")
        }
        let pending = InboxSnapshot(id: "personal", name: "Personal", unreadCount: 0,
                                    unreadMessages: [], recentMessages: [], readError: "Still loading")
        let partial = try MailRefresh.collect(at: path) {
            ReaderResult(inboxes: [work, pending], status: "partial", detail: "Still loading")
        }!
        check(partial.inboxes?.count == 2, "A new syncing inbox remains selectable")
        check(partial.messages == [item], "One slow inbox does not discard working inbox messages")
        check(partial.configured(inboxIDs: ["work"], unreadOnly: true).status == "ready", "Healthy selected inbox is not marked stale")
        let personal = partial.configured(inboxIDs: ["personal"], unreadOnly: true)
        check(personal.status == "partial" && personal.updatedAt == nil, "Never-loaded inbox shows pending, not caught up")
        var failedWork = work
        failedWork.name = "Renamed work"
        failedWork.unreadMessages = []
        failedWork.recentMessages = []
        failedWork.readError = "Still loading"
        failedWork.updatedAt = nil
        let stale = try MailRefresh.collect(at: path) {
            ReaderResult(inboxes: [failedWork, pending], status: "partial", detail: "Still loading")
        }!
        check(stale.inboxes?.first?.unreadMessages == [item], "Failed inbox preserves previous headers")
        check(stale.inboxes?.first?.name == "Renamed work", "Discovery updates renamed accounts even on failure")
        check(stale.configured(inboxIDs: ["work"], unreadOnly: true).updatedAt == checked, "Failed inbox retains its successful timestamp")
        check(SnapshotStore.load(from: path).inboxes?.first?.readError != nil, "Pending state survives cache roundtrip")
        let restored = try MailRefresh.collect(at: path) {
            ReaderResult(inboxes: [work], status: "ready", detail: "")
        }!
        check(restored.inboxes?.count == 1 && restored.inboxes?.first?.readError == nil, "Recovery clears error; removed accounts leave picker")
        let attributes = try FileManager.default.attributesOfItem(atPath:path.path)
        check((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Cache permissions remain private")
        print("PASS: refresh, failure preservation, lock exclusion, privacy, new syncing accounts, partial updates, scoped status, recovery")
    }
}
