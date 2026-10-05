import Foundation

@main
struct ConfigurationTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func main() {
        let date = Date(timeIntervalSince1970: 1_000)
        func item(_ id: Int, inbox: String, read: Bool = false) -> MailItem {
            MailItem(id: id, sender: "Example", subject: "Test", receivedAt: date,
                     messageID: "\(id)@example.com", isRead: read, inboxID: inbox)
        }
        let work = item(1, inbox: "work-id")
        let personal = item(2, inbox: "personal-id")
        let readWork = item(3, inbox: "work-id", read: true)
        var cache = MailSnapshot(messages: [personal, work], unreadCount: 50, updatedAt: date,
                                 status: "ready", detail: "", inboxes: [
            InboxSnapshot(id: "work-id", name: "Work · work@example.com", unreadCount: 10,
                          unreadMessages: [work], recentMessages: [readWork, work]),
            InboxSnapshot(id: "personal-id", name: "Personal · personal@example.com", unreadCount: 40,
                          unreadMessages: [personal], recentMessages: [personal])
        ])
        let options = InboxOptions.items(for: cache.inboxes!).items
        check(options == [InboxOptions.allInboxes, "work-id", "personal-id"], "Options store stable strings, not entities or display names")
        let config = MailConfiguration()
        config.unreadOnly = true
        check(config.snapshot(from: cache).status == "selectionRequired", "Old or unresolved configuration must ask for selection")
        check(config.snapshot(from: cache).messages.isEmpty, "Unresolved selection must not show all accounts")
        config.inboxIDs = []
        check(config.snapshot(from: cache).messages.isEmpty, "Clearing selection must not show all accounts")
        config.inboxIDs = ["work-id"]
        check(config.snapshot(from: cache).messages == [work], "Single-account widget excludes personal mail")
        check(config.snapshot(from: cache).unreadCount == 10, "Count must match selected account")
        check(config.scope(in: cache) == "Work", "Footer follows selected account")
        config.unreadOnly = false
        check(Set(config.snapshot(from: cache).messages.map(\.id)) == [1, 3], "All-mail mode still respects account selection")
        cache.inboxes![0].name = "Renamed · work@example.com"
        check(config.snapshot(from: cache).messages.count == 2, "Account rename preserves selection")
        check(config.scope(in: cache) == "Renamed", "Footer uses current account name")
        config.inboxIDs = ["work-id", "personal-id"]
        check(config.snapshot(from: cache).messages.count == 3, "Multiple selections merge mail")
        check(config.scope(in: cache) == "2 inboxes", "Multi-account footer")
        config.inboxIDs = [InboxOptions.allInboxes]
        check(config.snapshot(from: cache).unreadCount == 50, "Explicit All Inboxes includes every account")
        config.inboxIDs = ["removed-id"]
        check(config.snapshot(from: cache).messages.isEmpty, "Removed account must not fall back to all mail")
        config.inboxIDs = ["work-id"]
        cache.inboxes = nil
        check(config.snapshot(from: cache).messages.isEmpty, "Legacy unscoped cache must not leak other accounts")
        print("PASS: string options, missing/empty selection, single/multiple/all inboxes, unread/all mail, counts, rename and missing/legacy cache")
    }
}
