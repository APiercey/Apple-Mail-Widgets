import Foundation

struct ReaderResult: Decodable {
    var inboxes: [InboxSnapshot]?
    var messages: [MailItem]?
    var unreadCount: Int?
    var status: String
    var detail: String
}

enum MailReader {
    static func read() throws -> ReaderResult {
        let catalog = try invoke(arguments: ["catalog"], timeoutSeconds: 10)
        guard catalog.status == "catalog", let discovered = catalog.inboxes else { return catalog }
        let inboxes = discovered.map { inbox -> InboxSnapshot in
            do {
                let result = try invoke(arguments: [inbox.id], timeoutSeconds: 20)
                guard result.status == "ready", var loaded = result.inboxes?.first else {
                    throw NSError(domain: "UnreadMail", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: result.detail])
                }
                loaded.updatedAt = .now
                return loaded
            } catch {
                var pending = inbox
                pending.readError = "Apple Mail has not finished loading this inbox, or took too long to respond. Retrying automatically."
                return pending
            }
        }
        let pending = inboxes.filter { $0.readError != nil }
        return ReaderResult(inboxes: inboxes, status: pending.isEmpty ? "ready" : "partial",
                            detail: pending.isEmpty ? "" : "Some inboxes could not be checked yet. Last available messages are shown; new inboxes remain selectable. Retrying automatically.")
    }

    private static func invoke(arguments: [String], timeoutSeconds: Double) throws -> ReaderResult {
        guard let script = Bundle.main.url(forResource: "ReadMail", withExtension: "js") else {
            throw NSError(domain: "UnreadMail", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mail reader is missing."])
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", script.path] + arguments
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        if process.terminationStatus != 0 {
            let reason = String(data: errorData, encoding: .utf8) ?? ""
            if reason.contains("1743") || reason.contains("not authorized") || reason.contains("Not authorized") {
                return ReaderResult(status: "permissionRequired", detail: "Allow Mail Widgets to control Mail in System Settings → Privacy & Security → Automation.")
            }
            throw NSError(domain: "UnreadMail", code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: reason.isEmpty ? "Mail took too long to respond. Try again." : "Mail could not be read. \(reason.prefix(250))"])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(ReaderResult.self, from: data)
    }
}
