import Foundation

struct AgentStatus: Equatable {
    let installed: Bool
    let loaded: Bool
    let correctPath: Bool
    let approvalRequired: Bool
    var enabled: Bool { installed && loaded && correctPath && !approvalRequired }
    var needsRepair: Bool { installed && !enabled && !approvalRequired }
    var description: String {
        if approvalRequired { return "Allow Mail Widgets in System Settings → General → Login Items & Extensions." }
        if enabled { return "Checks Apple Mail about every minute, even when this app is quit." }
        if installed { return "Background refresh is configured but is not running correctly. Choose Repair." }
        return "Background refresh is off. Checks continue while this app is open." 
    }
}
