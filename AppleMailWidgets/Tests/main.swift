import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let messages = (0..<15).map { MailItem(id: $0, sender: "\"Example Sender\" <a@example.com>", subject: $0 == 14 ? "" : "Subject | \"quoted\"\nline", receivedAt: Date(timeIntervalSince1970: Double($0)), messageID: "test\($0)@example.com") }
let sample = MailSnapshot(messages: messages.shuffled(), unreadCount: 15, updatedAt: .now, status: "ready", detail: "")
let top = sample.newestTen()
check(top.messages.count == 10, "Must limit to ten")
check(top.messages.map(\.id) == Array((5..<15).reversed()), "Newest first")
check(top.unreadCount == 15, "Total count retained")
check(top.messages[0].displaySubject == "(No subject)", "Empty subject")
check(top.messages[0].displaySender == "Example Sender", "Sender formatting")
check(URLComponents(url: top.messages[0].openURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "messageID" })?.value == "test14@example.com", "Permanent message ID in deep link")
let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("snapshot.json")
try SnapshotStore.save(sample, to: path)
check(SnapshotStore.load(from: path) == top, "JSON roundtrip")
try Data("invalid".utf8).write(to: path)
check(SnapshotStore.load(from: path) == .empty, "Corrupt cache recovery")
try FileManager.default.removeItem(at: path.deletingLastPathComponent())
print("PASS: ordering, top ten, total count, sender/subject formatting, safe links, cache roundtrip and corrupt-cache recovery")

func item(_ id: Int, _ time: Double, read: Bool, inbox: String) -> MailItem {
    MailItem(id: id, sender: "Sender", subject: "Message \(id)", receivedAt: Date(timeIntervalSince1970: time),
             messageID: "\(id)@example.com", isRead: read, inboxID: inbox)
}
let aUnread = [item(101, 100, read: false, inbox: "a"), item(102, 80, read: false, inbox: "a")]
let bUnread = [item(201, 90, read: false, inbox: "b")]
let aRecent = [item(103, 110, read: true, inbox: "a")] + aUnread
let bRecent = [item(202, 105, read: true, inbox: "b")] + bUnread
let multi = MailSnapshot(messages: [], unreadCount: 57, updatedAt: .now, status: "ready", detail: "", inboxes: [
    InboxSnapshot(id: "a", name: "Personal", unreadCount: 40, unreadMessages: aUnread, recentMessages: aRecent),
    InboxSnapshot(id: "b", name: "Work", unreadCount: 17, unreadMessages: bUnread, recentMessages: bRecent),
    InboxSnapshot(id: "c", name: "Empty", unreadCount: 0, unreadMessages: [], recentMessages: [])
])
let widgetA = multi.configured(inboxIDs: ["a"], unreadOnly: true)
let widgetB = multi.configured(inboxIDs: ["b"], unreadOnly: false)
check(widgetA.messages.map(\.id) == [101,102], "Unread selection must only include selected inbox")
check(widgetB.messages.map(\.id) == [202,201], "All-mail mode must include read messages")
check(widgetA.unreadCount == 40 && widgetB.unreadCount == 17, "Unread counts follow inbox scope, not visible rows or mode")
check(multi.configured(inboxIDs: ["a","b"], unreadOnly: false).messages.map(\.id) == [103,202,101,201,102], "Merged all mail must be globally sorted")
check(multi.configured(inboxIDs: [], unreadOnly: true).messages.map(\.id) == [101,201,102], "Empty selection means all inboxes")
check(multi.configured(inboxIDs: ["b","b"], unreadOnly: true).unreadCount == 17, "Repeated selections must not double count")
check(multi.configured(inboxIDs: ["gone"], unreadOnly: true).messages.isEmpty, "Removed inbox must not leak unrelated mail")
check(multi.configured(inboxIDs: ["gone"], unreadOnly: true).status == "inboxUnavailable", "Missing inbox visible status")
check(multi.configured(inboxIDs: ["c"], unreadOnly: false).unreadCount == 0, "Empty inbox")
check(widgetA.messages.map(\.id) == [101,102], "Another widget's selection must not mutate this widget")
let longInbox = InboxSnapshot(id:"long",name:"Long",unreadCount:100,
    unreadMessages:(0..<30).map {item(300+$0,Double($0),read:false,inbox:"long")},recentMessages:[])
var larger = multi; larger.inboxes?.append(longInbox)
check(larger.configured(inboxIDs: [], unreadOnly: true).messages.count == 10, "Combined result still limited to ten")
let legacyJSON = "{\"messages\":[],\"unreadCount\":0,\"status\":\"ready\",\"detail\":\"\"}".data(using:.utf8)!
let legacy = try JSONDecoder().decode(MailSnapshot.self,from:legacyJSON)
check(legacy.inboxes == nil, "v1 cache migration")
check(multi.allCachedMessages.contains(where: {$0.id == 202}), "Links resolve messages outside the default unread list")
print("PASS: independent widget selection, mixed inbox sorting, read/all toggle, scoped unread counts, missing/empty inboxes, multi-inbox top ten, legacy cache, link lookup")
