import Foundation

struct MailItem: Codable, Identifiable, Equatable {
    let id: Int
    let sender: String
    let subject: String
    let receivedAt: Date
    let messageID: String
    var isRead: Bool? = nil
    var inboxID: String? = nil

    var displaySender: String {
        let name = sender.components(separatedBy: " <").first ?? sender
        return name.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }
    var displaySubject: String { subject.isEmpty ? "(No subject)" : subject }
    var openURL: URL {
        var url = URLComponents()
        url.scheme = "applemailwidgets"
        url.host = "message"
        url.queryItems = [URLQueryItem(name: "id", value: String(id)),
                          URLQueryItem(name: "messageID", value: messageID)]
        return url.url!
    }
}

struct InboxSnapshot: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var unreadCount: Int
    var unreadMessages: [MailItem]
    var recentMessages: [MailItem]
    var updatedAt: Date? = nil
    var readError: String? = nil
}

struct MailSnapshot: Codable, Equatable {
    var messages: [MailItem]
    var unreadCount: Int
    var updatedAt: Date?
    var status: String
    var detail: String
    var inboxes: [InboxSnapshot]? = nil

    static let empty = MailSnapshot(messages: [], unreadCount: 0, updatedAt: nil,
        status: "setup", detail: "Open AppleMailWidgets to connect Apple Mail.")

    static func newest(_ messages: [MailItem], limit: Int = 10) -> [MailItem] {
        var seen = Set<Int>()
        return Array(messages.sorted {
            $0.receivedAt == $1.receivedAt ? $0.id > $1.id : $0.receivedAt > $1.receivedAt
        }.filter { seen.insert($0.id).inserted }.prefix(limit))
    }
    func newestTen() -> MailSnapshot {
        var value = self
        value.messages = Self.newest(messages)
        value.inboxes = inboxes?.map {
            var inbox = $0
            inbox.unreadMessages = Self.newest(inbox.unreadMessages)
            inbox.recentMessages = Self.newest(inbox.recentMessages)
            return inbox
        }
        return value
    }
    /// An empty selection means all inboxes; missing selected inboxes never fall back to other mail.
    func configured(inboxIDs: [String], unreadOnly: Bool) -> MailSnapshot {
        guard let inboxes else {
            // Old caches cannot prove which account owns a message.
            guard !inboxIDs.isEmpty else { return newestTen() }
            var result = self
            result.messages = []
            result.unreadCount = 0
            result.status = "inboxUnavailable"
            result.detail = "Refresh AppleMailWidgets to load the selected inbox."
            return result
        }
        let selected = Set(inboxIDs)
        let chosen = inboxes.filter { selected.isEmpty || selected.contains($0.id) }
        var result = self
        result.messages = Self.newest(chosen.flatMap { unreadOnly ? $0.unreadMessages : $0.recentMessages })
        result.unreadCount = chosen.reduce(0) { $0 + $1.unreadCount }
        if status == "ready" || status == "partial" {
            let pending = chosen.filter { $0.readError != nil }
            result.status = pending.isEmpty ? "ready" : "partial"
            result.detail = pending.first?.readError ?? ""
            if chosen.contains(where: { $0.updatedAt != nil || $0.readError != nil }) {
                result.updatedAt = chosen.compactMap(\.updatedAt).min()
            }
        }
        if !selected.isEmpty && chosen.count != selected.count {
            result.status = "inboxUnavailable"
            result.detail = "A selected inbox is unavailable. Edit this widget to update its inboxes."
        }
        return result
    }
    var allCachedMessages: [MailItem] {
        messages + (inboxes ?? []).flatMap { $0.recentMessages + $0.unreadMessages }
    }
}

enum SnapshotStore {
    static let widgetID = "com.applemailwidgets.AppleMailWidgets.Widget"
    static var url: URL {
        #if WIDGET_EXTENSION
        let root = FileManager.default.homeDirectoryForCurrentUser
        #else
        // The locally signed host publishes into the widget's container.
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(widgetID)/Data", isDirectory: true)
        #endif
        return root.appendingPathComponent("Library/Application Support/AppleMailWidgets/snapshot.json")
    }
    static func load(from path: URL = url) -> MailSnapshot {
        guard let data = try? Data(contentsOf: path),
              let snapshot = try? JSONDecoder().decode(MailSnapshot.self, from: data) else { return .empty }
        return snapshot.newestTen()
    }
    static func save(_ snapshot: MailSnapshot, to path: URL = url) throws {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(snapshot.newestTen())
        try data.write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }
}
