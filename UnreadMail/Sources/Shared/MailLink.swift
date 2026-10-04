import Foundation

enum MailDestination: Equatable {
    case settings
    case inbox
    case message(URL)
}

enum MailLink {
    static func messageURL(_ rawID: String) -> URL? {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        guard !id.isEmpty, !id.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let escaped = ("<" + id + ">").addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "message://" + escaped)
    }
    static func destination(for url: URL, snapshot: MailSnapshot) -> MailDestination {
        guard url.scheme == "unreadmail" else { return .inbox }
        if url.host == "settings" { return .settings }
        guard url.host == "message" else { return .inbox }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let messageID = items.first(where: { $0.name == "messageID" })?.value,
           let destination = messageURL(messageID) { return .message(destination) }
        // Older installed widget timelines only contain the local numeric ID.
        if let raw = items.first(where: { $0.name == "id" })?.value,
           let id = Int(raw), let message = snapshot.allCachedMessages.first(where: { $0.id == id }),
           let destination = messageURL(message.messageID) { return .message(destination) }
        return .inbox
    }
}
