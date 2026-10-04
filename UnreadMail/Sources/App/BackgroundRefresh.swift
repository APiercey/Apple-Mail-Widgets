import AppKit
import ServiceManagement
import WidgetKit

@MainActor
enum BackgroundRefresh {
    static let label = "local.alexbp.UnreadMail.Refresh"
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static func inspect() -> AgentStatus {
        let installed = FileManager.default.fileExists(atPath: plistURL.path)
        guard installed else { return AgentStatus(installed: false, loaded: false, correctPath: false, approvalRequired: false) }
        let data = try? Data(contentsOf: plistURL)
        let plist = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]
        let arguments = plist?["ProgramArguments"] as? [String]
        let correctPath = arguments?.first == Bundle.main.executableURL?.path
        let loaded = jobIsLoaded()
        // Legacy-plist status can report notFound for an active local agent. launchd is authoritative.
        let requiresApproval = !loaded && SMAppService.statusForLegacyPlist(at: plistURL) == .requiresApproval
        return AgentStatus(installed: true, loaded: loaded, correctPath: correctPath, approvalRequired: requiresApproval)
    }
    static var enabled: Bool { inspect().enabled }
    static var requested: Bool { FileManager.default.fileExists(atPath: plistURL.path) }
    static var statusText: String { inspect().description }
    private static func jobIsLoaded() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(getuid())/\(label)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 }
        catch { return false }
    }
    @discardableResult
    private static func launchctl(_ arguments: [String], allowMissing: Bool = false) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let status = process.terminationStatus
        if status != 0 && !(allowMissing && status == 113) {
            throw NSError(domain: "MailWidgets.BackgroundRefresh", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Background refresh could not be configured."
            ])
        }
        return status
    }
    static func setEnabled(_ enabled: Bool) throws {
        let domain = "gui/\(getuid())"
        if enabled {
            guard let executable = Bundle.main.executableURL else { return }
            if jobIsLoaded() { try launchctl(["bootout", "\(domain)/\(label)"], allowMissing: true) }
            let configuration: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable.path, "--refresh-agent"],
                "RunAtLoad": true,
                "StartInterval": 60,
                "ProcessType": "Background",
                "LimitLoadToSessionType": "Aqua",
                "AssociatedBundleIdentifiers": ["local.alexbp.UnreadMail"]
            ]
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: configuration, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: plistURL.path)
            do { try launchctl(["bootstrap", domain, plistURL.path]) }
            catch {
                try? FileManager.default.removeItem(at: plistURL)
                throw error
            }
        } else if requested {
            try launchctl(["bootout", "\(domain)/\(label)"], allowMissing: true)
            try FileManager.default.removeItem(at: plistURL)
        }
    }
    static func runOnce() -> Int32 {
        guard UserDefaults.standard.bool(forKey: "connected") else { return 0 }
        do {
            if let snapshot = try MailRefresh.collect() {
                WidgetCenter.shared.reloadTimelines(ofKind: "UnreadMailWidget")
                // Give the WidgetCenter IPC request time to leave this short-lived process.
                RunLoop.current.run(until: Date().addingTimeInterval(1))
                print("Background refresh: \(snapshot.status)")
            }
            return 0
        } catch {
            fputs("Background refresh could not save the widget cache.\n", stderr)
            return 1
        }
    }
}

@main
struct MailWidgetsMain {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--refresh-agent") || arguments.contains("--enable-background") || arguments.contains("--disable-background") || arguments.contains("--background-status") {
            // Do not initialize NSApplication here: launchd runs must not register
            // as the visible app or intercept attempts to open its settings window.
            if arguments.contains("--refresh-agent") { exit(BackgroundRefresh.runOnce()) }
            do {
                if arguments.contains("--enable-background") { try BackgroundRefresh.setEnabled(true) }
                if arguments.contains("--disable-background") { try BackgroundRefresh.setEnabled(false) }
                print(BackgroundRefresh.statusText)
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
                exit(1)
            }
        } else {
            SettingsApplication.run()
        }
    }
}
