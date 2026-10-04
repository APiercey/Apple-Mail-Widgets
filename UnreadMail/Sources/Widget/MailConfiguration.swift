import AppIntents
import Foundation

struct InboxEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Inbox"
    static var defaultQuery = InboxQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct InboxQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [InboxEntity] {
        let available = SnapshotStore.load().inboxes ?? []
        return identifiers.map { id in
            InboxEntity(id: id, name: available.first(where: { $0.id == id })?.name ?? "Unavailable inbox")
        }
    }
    func suggestedEntities() async throws -> [InboxEntity] {
        (SnapshotStore.load().inboxes ?? []).map { InboxEntity(id: $0.id, name: $0.name) }
    }
}
struct MailConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Mail"
    static var description = IntentDescription("Choose inboxes and which recent messages to show. Leave Inboxes empty to include all inboxes.")

    @Parameter(title: "Inboxes", description: "Leave empty for all inboxes.")
    var inboxes: [InboxEntity]?

    @Parameter(title: "Only unread", default: true)
    var unreadOnly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$inboxes
            \.$unreadOnly
        }
    }
}
