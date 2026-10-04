import Foundation
@main struct MailLinkTests {
    static func main() {
        let item = MailItem(id: 42, sender: "Example", subject: "Test", receivedAt: .now, messageID: "<abc+quotes%?&/#@example.com>")
        guard case .message(let direct) = MailLink.destination(for:item.openURL,snapshot:.empty) else { fatalError("Link must work after the cache changes") }
        precondition(direct.absoluteString.removingPercentEncoding == "message://<abc+quotes%?&/#@example.com>")
        let cached = MailSnapshot(messages:[item],unreadCount:1,updatedAt:.now,status:"ready",detail:"")
        precondition(item.openURL.scheme == "applemailwidgets")
        precondition(MailLink.destination(for:URL(string:"unrelated://settings")!,snapshot:cached) == .inbox)
        precondition(MailLink.destination(for:URL(string:"applemailwidgets://message?id=42")!,snapshot:cached) == .message(direct))
        precondition(MailLink.destination(for:URL(string:"applemailwidgets://message?id=9999")!,snapshot:cached) == .inbox)
        precondition(MailLink.destination(for:URL(string:"applemailwidgets://open")!,snapshot:cached) == .inbox)
        precondition(MailLink.destination(for:URL(string:"applemailwidgets://open-mail")!,snapshot:cached) == .inbox)
        precondition(MailLink.destination(for:URL(string:"applemailwidgets://settings")!,snapshot:cached) == .settings)
        precondition(MailLink.messageURL("") == nil)
        precondition(MailLink.messageURL("a\nb@example.com") == nil)
        print("PASS: permanent message IDs, escaping, legacy links, missing messages, inbox/settings routing, invalid IDs")
    }
}
