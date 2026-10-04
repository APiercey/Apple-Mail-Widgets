import Foundation
@main struct AgentStatusTests {
    static func main() {
        let active = AgentStatus(installed:true,loaded:true,correctPath:true,approvalRequired:false)
        precondition(active.enabled && !active.needsRepair)
        let unloaded = AgentStatus(installed:true,loaded:false,correctPath:true,approvalRequired:false)
        precondition(!unloaded.enabled && unloaded.needsRepair)
        let moved = AgentStatus(installed:true,loaded:true,correctPath:false,approvalRequired:false)
        precondition(!moved.enabled && moved.needsRepair)
        let denied = AgentStatus(installed:true,loaded:false,correctPath:true,approvalRequired:true)
        precondition(!denied.enabled && !denied.needsRepair)
        let absent = AgentStatus(installed:false,loaded:false,correctPath:false,approvalRequired:false)
        precondition(!absent.enabled && !absent.needsRepair)
        print("PASS: active, unloaded, moved, approval-required, and disabled agent states")
    }
}
