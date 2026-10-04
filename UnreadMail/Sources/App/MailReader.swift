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
        guard let script = Bundle.main.url(forResource: "ReadMail", withExtension: "js") else {
            throw NSError(domain: "UnreadMail", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mail reader is missing."])
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", script.path]
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 45, execute: timeout)
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
