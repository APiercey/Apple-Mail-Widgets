import AppIntents
import Foundation

// Primitive values do not need AppEntity registration, which fails for ad-hoc
// signed source builds. Keep the stable account ID separate from its display name.
struct InboxOptions: DynamicOptionsProvider {
    static let allInboxes = "applemailwidgets:all-inboxes"

    func results() async throws -> IntentItemCollection<String> {
        Self.items(for: SnapshotStore.load().inboxes ?? [])
    }

    static func items(for inboxes: [InboxSnapshot]) -> IntentItemCollection<String> {
        let items = [IntentItem(allInboxes, title: "All Inboxes")] + inboxes.map {
            IntentItem($0.id, title: "\($0.name)")
        }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
    }
}

struct MailConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Mail"
    static var description = IntentDescription("Choose inboxes and which recent messages to show. Choose All Inboxes to include every account.")

    // Use a new key so previously stored AppEntity objects are not decoded as strings.
    // Missing selections must ask for setup, never silently show unrelated inboxes.
    @Parameter(title: "Inboxes", optionsProvider: InboxOptions())
    var inboxIDs: [String]?

    @Parameter(title: "Only unread", default: true)
    var unreadOnly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$inboxIDs
            \.$unreadOnly
        }
    }

    func snapshot(from source: MailSnapshot) -> MailSnapshot {
        guard let inboxIDs, !inboxIDs.isEmpty else {
            var result = source
            result.messages = []
            result.unreadCount = 0
            result.status = "selectionRequired"
            result.detail = "Edit this widget and choose its inboxes, or choose All Inboxes."
            return result
        }
        return source.configured(inboxIDs: inboxIDs.contains(InboxOptions.allInboxes) ? [] : inboxIDs,
                                 unreadOnly: unreadOnly)
    }

    func scope(in source: MailSnapshot) -> String {
        guard let inboxIDs, !inboxIDs.isEmpty else { return "Choose inboxes" }
        if inboxIDs.contains(InboxOptions.allInboxes) { return "All Inboxes" }
        let ids = Set(inboxIDs)
        guard ids.count == 1 else { return "\(ids.count) inboxes" }
        return source.inboxes?.first(where: { ids.contains($0.id) })?.name.components(separatedBy: " · ")[0]
            ?? "Unavailable inbox"
    }
}
