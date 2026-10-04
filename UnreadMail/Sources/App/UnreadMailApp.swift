import AppKit
import SwiftUI
import WidgetKit
import ServiceManagement

@MainActor
final class MailModel: ObservableObject {
    @Published var snapshot = SnapshotStore.load()
    @Published var refreshing = false
    @Published var storageError: String?
    @Published var agentStatus = BackgroundRefresh.inspect()
    var backgroundRefresh: Bool { agentStatus.enabled }
    private var timer: Timer?
    private var cacheTimer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateBackgroundStatus()
                if !self.agentStatus.enabled { self.refresh() }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        cacheTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.refreshing else { return }
                self.updateBackgroundStatus()
                let latest = SnapshotStore.load()
                if latest != self.snapshot { self.snapshot = latest }
            }
        }
        if UserDefaults.standard.bool(forKey: "connected") { refresh() }
    }
    func connect() {
        UserDefaults.standard.set(true, forKey: "connected")
        guard let mailURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: mailURL, configuration: configuration) { _, _ in
            Task { @MainActor in self.refresh() }
        }
    }
    func refresh() {
        guard !refreshing, UserDefaults.standard.bool(forKey: "connected") else { return }
        refreshing = true
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<MailSnapshot?, Error> in
                Result { try MailRefresh.collect() }
            }.value
            switch result {
            case .success(let next):
                storageError = nil
                snapshot = next ?? SnapshotStore.load()
                if next != nil { WidgetCenter.shared.reloadTimelines(ofKind: "UnreadMailWidget") }
            case .failure(let error):
                storageError = "The widget cache could not be saved: \(error.localizedDescription)"
            }
            refreshing = false
        }
    }
    func updateBackgroundStatus() {
        let status = BackgroundRefresh.inspect()
        if status != agentStatus { agentStatus = status }
    }
    func setBackgroundRefresh(_ enabled: Bool) {
        do {
            try BackgroundRefresh.setEnabled(enabled)
            storageError = nil
        } catch { storageError = error.localizedDescription }
        updateBackgroundStatus()
    }
}

struct ContentView: View {
    @ObservedObject var model: MailModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill").font(.system(size: 32)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mail Widgets").font(.title.bold())
                    Text("Apple Mail on your desktop").foregroundStyle(.secondary)
                }
                Spacer()
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(model.snapshot.status == "ready" ? "Last mail check successful" : "Apple Mail connection",
                              systemImage: model.snapshot.status == "ready" ? "checkmark.circle.fill" : "envelope")
                        Spacer()
                        Button(model.snapshot.updatedAt == nil ? "Connect Apple Mail" : "Open Mail") { model.connect() }
                    }
                    if !model.snapshot.detail.isEmpty {
                        Text(model.snapshot.detail).font(.callout).foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Last checked").font(.caption).foregroundStyle(.secondary)
                            if let date = model.snapshot.updatedAt {
                                Text(date, format: .dateTime.hour().minute().second()).monospacedDigit()
                            } else { Text("Not yet connected") }
                        }
                        Spacer()
                        if model.refreshing { ProgressView().controlSize(.small) }
                        Button("Refresh now", systemImage: "arrow.clockwise") { model.refresh() }
                            .disabled(model.refreshing || model.snapshot.status == "setup")
                    }
                }.padding(8)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Toggle("Refresh in background", isOn: Binding(get: { model.backgroundRefresh }, set: { model.setBackgroundRefresh($0) }))
                        Spacer()
                        if model.agentStatus.needsRepair {
                            Button("Repair") { model.setBackgroundRefresh(true) }
                        }
                    }
                    Text(model.agentStatus.description).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Keep Apple Mail running. macOS controls when widgets redraw.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            if let error = model.storageError {
                Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange)
            }
            GroupBox("Add a widget") {
                VStack(alignment: .leading, spacing: 10) {
                    instruction(1, "Control-click the desktop and choose **Edit Widgets**.")
                    instruction(2, "Find **Mail Widgets**, choose a size, and add a **Mail** widget.")
                    instruction(3, "Control-click your widget and choose **Edit “Mail”**.")
                    instruction(4, "Choose one or more inboxes. Leave the selection empty for all inboxes.")
                    instruction(5, "Keep **Only unread** on for unread messages, or turn it off to show all recent mail.")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
        }.padding(24).frame(width: 540)
    }

    private func instruction(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).")
                .monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
