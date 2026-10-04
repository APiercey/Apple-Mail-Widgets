import SwiftUI
import WidgetKit
import AppIntents

struct MailEntry: TimelineEntry {
    let date: Date
    let snapshot: MailSnapshot
    let configuration: MailConfiguration
    var scope: String {
        guard let chosen = configuration.inboxes, !chosen.isEmpty else { return "All Inboxes" }
        return chosen.count == 1 ? chosen[0].name.components(separatedBy: " · ")[0] : "\(chosen.count) inboxes"
    }
}
struct MailProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MailEntry {
        MailEntry(date: .now, snapshot: .empty, configuration: MailConfiguration())
    }
    func snapshot(for configuration: MailConfiguration, in context: Context) async -> MailEntry {
        entry(configuration)
    }
    func timeline(for configuration: MailConfiguration, in context: Context) async -> Timeline<MailEntry> {
        Timeline(entries: [entry(configuration)], policy: .after(.now.addingTimeInterval(300)))
    }
    private func entry(_ configuration: MailConfiguration) -> MailEntry {
        MailEntry(date: .now, snapshot: SnapshotStore.load().configured(
            inboxIDs: configuration.inboxes?.map(\.id) ?? [], unreadOnly: configuration.unreadOnly), configuration: configuration)
    }
}
struct MailWidgetView: View {
    let entry: MailEntry
    @Environment(\.widgetFamily) private var family
    private var limit: Int { family == .systemMedium ? 3 : 10 }
    private var twoColumns: Bool { family == .systemExtraLarge }
    private var sectionSpacing: CGFloat { family == .systemMedium ? 4 : (twoColumns ? 12 : 8) }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
                HStack(spacing: 7) {
                    Image(systemName: "envelope.fill").foregroundStyle(.tint)
                    Text("Mail").font(.headline)
                    Spacer()
                    Text(entry.snapshot.updatedAt == nil || entry.snapshot.status == "partial" ? "— unread" : "\(entry.snapshot.unreadCount) unread")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                if entry.snapshot.updatedAt == nil || entry.snapshot.messages.isEmpty {
                    emptyState.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    // Allocate the actual space left after the header and footer to rows.
                    GeometryReader { geometry in
                        let rowHeight = geometry.size.height / CGFloat(twoColumns ? 5 : limit)
                        if twoColumns {
                            HStack(alignment: .top, spacing: 24) {
                                column(Array(entry.snapshot.messages.prefix(5)), rowHeight: rowHeight)
                                column(Array(entry.snapshot.messages.dropFirst(5).prefix(5)), rowHeight: rowHeight)
                            }
                        } else {
                            column(Array(entry.snapshot.messages.prefix(limit)), rowHeight: rowHeight)
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text(entry.scope).lineLimit(1)
                    Spacer(minLength: 8)
                    if entry.snapshot.status != "ready" && entry.snapshot.updatedAt != nil {
                        Image(systemName: "exclamationmark.circle")
                        Text("Cached")
                    } else if let updated = entry.snapshot.updatedAt {
                        Text("Updated")
                        Text(updated, style: .time)
                    } else { Text("Open to connect") }
                }.font(.caption2).foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: entry.snapshot.updatedAt == nil ? "applemailwidgets://settings" : "applemailwidgets://open-mail"))
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: entry.snapshot.status == "ready" ? "checkmark.circle" : "envelope")
                .font(.title2).foregroundStyle(.secondary)
            Text(entry.snapshot.status == "ready" ? (entry.configuration.unreadOnly ? "All caught up" : "No messages") : "Mail needs attention")
                .font(.headline)
            Text(entry.snapshot.status == "ready" ? "No \(entry.configuration.unreadOnly ? "unread " : "")messages in these inboxes." : entry.snapshot.detail)
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func column(_ messages: [MailItem], rowHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(messages) { message in
                Link(destination: message.openURL) {
                    // Keep each sender/subject pair together, leaving room between messages.
                    VStack(alignment: .leading, spacing: twoColumns ? 5 : 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(message.displaySender).fontWeight(message.isRead == true ? .regular : .semibold)
                            Spacer(minLength: 0)
                            Text(message.receivedAt, format: .dateTime.day().month(.abbreviated))
                                .font(.caption2).foregroundStyle(.secondary)
                        }.font(twoColumns ? .body : .caption).lineLimit(1)
                        Text(message.displaySubject).font(twoColumns ? .callout : .caption2)
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: rowHeight)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }

}
@main
struct AppleMailWidgetsWidget: Widget {
    let kind = "AppleMailWidgetsWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MailConfiguration.self, provider: MailProvider()) {
            MailWidgetView(entry: $0)
        }
        .configurationDisplayName("Mail")
        .description("Your most recent messages. Choose inboxes and unread or all mail separately for each widget.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}
