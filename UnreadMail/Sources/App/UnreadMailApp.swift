import AppKit
import SwiftUI
import WidgetKit
import ServiceManagement

@MainActor
final class MailModel: ObservableObject {
    @Published var snapshot = SnapshotStore.load()
    @Published var refreshing = false
    @Published var storageError: String?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var backgroundRefresh = BackgroundRefresh.requested
    @Published var backgroundStatus = BackgroundRefresh.statusText
    private var timer: Timer?
    private var cacheTimer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateBackgroundStatus()
                if !BackgroundRefresh.enabled { self.refresh() }
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
        let requested = BackgroundRefresh.requested
        let text = BackgroundRefresh.statusText
        if backgroundRefresh != requested { backgroundRefresh = requested }
        if backgroundStatus != text { backgroundStatus = text }
    }
    func setBackgroundRefresh(_ enabled: Bool) {
        do {
            try BackgroundRefresh.setEnabled(enabled)
            storageError = nil
        } catch { storageError = error.localizedDescription }
        updateBackgroundStatus()
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch { storageError = error.localizedDescription }
    }
    func openMessage(_ item: MailItem) {
        // RFC Message-ID is encoded as a URL component; no email text is executed as code.
        let id = item.messageID.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        if !id.isEmpty,
           let escaped = ("<" + id + ">").addingPercentEncoding(withAllowedCharacters: .alphanumerics),
           let url = URL(string: "message://" + escaped) {
            NSWorkspace.shared.open(url)
        } else { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mail.app")) }
    }
    func handle(_ url: URL) {
        if url.host == "message",
           let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: {$0.name == "id"})?.value,
           let id = Int(raw), let message = snapshot.allCachedMessages.first(where: {$0.id == id}) {
            openMessage(message)
        } else { NSApp.activate(ignoringOtherApps: true) }
    }
}

struct ContentView: View {
    @ObservedObject var model: MailModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "envelope.badge.fill").font(.system(size: 35)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mail Widgets").font(.largeTitle.bold())
                    Text("Your inbox, at a glance.").foregroundStyle(.secondary)
                }
                Spacer()
                if model.refreshing { ProgressView().controlSize(.small) }
                Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }
                    .disabled(model.refreshing || model.snapshot.status == "setup")
            }
            GroupBox {
                HStack {
                    Label(model.snapshot.status == "ready" ? "Connected to Apple Mail" : "Apple Mail connection",
                          systemImage: model.snapshot.status == "ready" ? "checkmark.circle.fill" : "envelope")
                    Spacer()
                    Button(model.snapshot.updatedAt == nil ? "Connect Apple Mail" : "Open Mail") { model.connect() }
                        .buttonStyle(.borderedProminent)
                }.padding(6)
                if !model.snapshot.detail.isEmpty {
                    Text(model.snapshot.detail).font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
            }
            if let error = model.storageError {
                Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange)
            }
            HStack {
                Text("Newest unread").font(.headline)
                Spacer()
                if model.snapshot.updatedAt != nil {
                    Text("\(model.snapshot.unreadCount) unread · showing \(model.snapshot.messages.count)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            List {
                if model.snapshot.messages.isEmpty {
                    ContentUnavailableView(model.snapshot.status == "ready" ? "All caught up" : "Your messages will appear here",
                        systemImage: model.snapshot.status == "ready" ? "checkmark.circle" : "tray",
                        description: Text(model.snapshot.status == "ready" ? "No unread messages in your inboxes." : "Connect Apple Mail to show your ten newest unread messages."))
                }
                ForEach(model.snapshot.messages) { message in
                    Button { model.openMessage(message) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(.tint).frame(width: 6, height: 6).padding(.top, 6)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(message.displaySender).fontWeight(.semibold).lineLimit(1)
                                Text(message.displaySubject).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(message.receivedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.listStyle(.inset).clipShape(RoundedRectangle(cornerRadius: 8))
            GroupBox("Add your native widget") {
                Text("Control-click the desktop → Edit Widgets → Mail Widgets. Choose Large for ten messages. Control-click each widget → Edit “Mail” to choose its inboxes and turn Only unread on or off.")
                    .frame(maxWidth: .infinity, alignment: .leading).padding(6)
            }
            HStack {
                Toggle("Open app at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLogin($0) }))
                Spacer()
                if let date = model.snapshot.updatedAt {
                    Text("Updated \(date.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary)
                }
            }.font(.caption)
            Toggle("Refresh in background", isOn: Binding(get: { model.backgroundRefresh }, set: { model.setBackgroundRefresh($0) }))
                .font(.caption)
            Text(model.backgroundStatus + " Apple Mail must be running. macOS schedules widget redraws.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(minWidth: 540, idealWidth: 640, minHeight: 700, idealHeight: 820)
    }
}

struct UnreadMailApp: App {
    @StateObject private var model = MailModel()
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        WindowGroup("Mail Widgets", id: "main") {
            ContentView(model: model).onOpenURL { model.handle($0) }
        }.defaultSize(width: 640, height: 820)
        MenuBarExtra("Mail Widgets", systemImage: "envelope.badge") {
            Text("\(model.snapshot.unreadCount) unread messages")
            Button("Refresh now") { model.refresh() }.disabled(model.refreshing)
            Toggle("Refresh in background", isOn: Binding(get: { model.backgroundRefresh }, set: { model.setBackgroundRefresh($0) }))
            Button("Open Mail Widgets") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Divider()
            Button("Quit Mail Widgets") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
