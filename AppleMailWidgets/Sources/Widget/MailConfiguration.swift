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

    // App Intents requires a literal bound. This is the native Int limit, not a day-count cap.
    @Parameter(title: "Last X days", description: "1 means today, 2 includes yesterday. Leave blank for any date.",
               controlStyle: .field, inclusiveRange: (1, 9223372036854775807))
    var lastDays: Int?

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$inboxIDs
            \.$unreadOnly
            \.$lastDays
        }
    }

    func snapshot(from source: MailSnapshot, now: Date = .now, calendar: Calendar = .current) -> MailSnapshot {
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
            .filtered(lastDays: lastDays, now: now, calendar: calendar)
    }

    var dateScope: String? {
        guard let lastDays else { return nil }
        return lastDays <= 1 ? "today" : "in the last \(lastDays) days"
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
