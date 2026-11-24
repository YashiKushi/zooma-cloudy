import SwiftUI
import NetworkExtension

@main
struct HappVPNApp: App {
    @StateObject private var vpnManager = VPNManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
        }
    }
}

