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
        let attributes = try FileManager.default.attributesOfItem(atPath:path.path)
        check((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Cache permissions remain private")
        print("PASS: refresh success, preserved cache on error/Mail closed, concurrent-run exclusion, lock release, private cache")
    }
}
