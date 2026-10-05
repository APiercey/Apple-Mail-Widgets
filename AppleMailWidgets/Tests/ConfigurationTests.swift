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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let formatter = ISO8601DateFormatter()
        func parseDate(_ value: String) -> Date { formatter.date(from: value)! }
        let now = parseDate("2026-10-05T12:00:00+02:00")
        func datedItem(_ id: Int, _ value: String, inbox: String = "work-id", read: Bool = false) -> MailItem {
            MailItem(id: id, sender: "Example", subject: "Date test", receivedAt: parseDate(value),
                     messageID: "\(id)@example.com", isRead: read, inboxID: inbox)
        }
        let today = datedItem(10, "2026-10-05T00:00:00+02:00")
        let yesterday = datedItem(11, "2026-10-04T23:59:59+02:00")
        let older = datedItem(12, "2026-10-03T23:59:59+02:00")
        let readToday = datedItem(13, "2026-10-05T08:00:00+02:00", read: true)
        let personalToday = datedItem(14, "2026-10-05T10:00:00+02:00", inbox: "personal-id")
        let datedCache = MailSnapshot(messages: [], unreadCount: 50, updatedAt: now, status: "ready", detail: "", inboxes: [
            InboxSnapshot(id: "work-id", name: "Work", unreadCount: 10,
                          unreadMessages: [today, yesterday, older], recentMessages: [readToday, today, yesterday, older]),
            InboxSnapshot(id: "personal-id", name: "Personal", unreadCount: 40,
                          unreadMessages: [personalToday], recentMessages: [personalToday])
        ])
        config.inboxIDs = ["work-id"]
        config.unreadOnly = true
        config.lastDays = 1
        func filtered(at time: Date = now) -> MailSnapshot {
            config.snapshot(from: datedCache, now: time, calendar: calendar)
        }
        check(filtered().messages == [today], "Today includes local midnight and excludes one second before it and other accounts")
        check(filtered().unreadCount == 10, "Unread total remains scoped to selected inboxes across all dates")
        config.lastDays = 2
        check(filtered().messages == [today, yesterday], "Two days includes today and yesterday only")
        config.lastDays = nil
        check(filtered().messages.count == 3, "Existing widgets without a date setting keep all dates")
        config.lastDays = Int.max
        check(filtered().messages.count == 3, "Very large day counts work without overflow or a product cap")
        config.lastDays = 0
        check(filtered().messages == [today], "Invalid zero input is clamped to one day")
        config.lastDays = Int.min
        check(filtered().messages == [today], "Invalid negative input cannot overflow")
        config.lastDays = 1
        config.unreadOnly = false
        check(filtered().messages == [readToday, today], "Date window works in all-mail mode")
        config.inboxIDs = [InboxOptions.allInboxes]
        check(filtered().messages == [personalToday, readToday, today], "All Inboxes is still sorted within the date window")
        check(filtered(at: parseDate("2026-10-06T00:00:00+02:00")).messages.isEmpty, "Today expires at the next local midnight")
        // Calendar days must follow 23- and 25-hour DST days, not rolling 24-hour periods.
        for (boundary, nextDay) in [("2026-03-29T00:00:00+01:00", "2026-03-30T12:00:00+02:00"),
                                     ("2026-10-25T00:00:00+02:00", "2026-10-26T12:00:00+01:00")] {
            var dst = datedCache
            let edge = datedItem(20, boundary)
            let before = MailItem(id: 21, sender: "Example", subject: "Before", receivedAt: edge.receivedAt.addingTimeInterval(-1), messageID: "before")
            dst.messages = [edge, before]
            check(dst.filtered(lastDays: 2, now: parseDate(nextDay), calendar: calendar).messages == [edge], "DST calendar boundary")
        }
        config.lastDays = nil
        config.inboxIDs = ["work-id"]
        cache.inboxes = nil
        check(config.snapshot(from: cache).messages.isEmpty, "Legacy unscoped cache must not leak other accounts")
        print("PASS: inbox selection, unread/all mail, dates, local midnight, DST, unlimited days, counts and legacy cache")
    }
}
