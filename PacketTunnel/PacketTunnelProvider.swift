import Foundation
import NetworkExtension

#if canImport(Libbox)
import Libbox

public class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var provider: PacketTunnelProvider?
    
    init(_ provider: PacketTunnelProvider) {
        self.provider = provider
        super.init()
    }
    
    public func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        if let fd = provider?.packetFlow.value(forKeyPath: "fileDescriptor") as? Int32 {
            ret0_?.pointee = fd
        } else {
            ret0_?.pointee = 0
        }
    }
    
    public func usePlatformAutoDetectControl() -> Bool {
        return false
    }
    
    public func autoDetectControl(_ fd: Int32) throws {
    }
    
    public func writeLog(_ message: String?) {
        NSLog("[sing-box] %@", message ?? "")
    }
    
    public func useProcFS() -> Bool {
        return false
    }
    
    public func underNetworkExtension() -> Bool {
        return true
    }
    
    public func includeAllNetworks() -> Bool {
        return false
    }
    
    public func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol? {
        return nil
    }
    
    public func readWIFIState() -> LibboxWIFIState? {
        return nil
    }
    
    public func packageName(byUid uid: Int32, error: NSErrorPointer) -> String {
        return ""
    }
    
    public func uid(byPackageName packageName: String?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        ret0_?.pointee = 0
    }
}
#endif

class PacketTunnelProvider: NEPacketTunnelProvider {

#if canImport(Libbox)
    private var boxService: LibboxBoxService?
#endif

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.19.0.1")
        
        let ipv4Settings = NEIPv4Settings(addresses: ["172.19.0.2"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelNetworkSettings.ipv4Settings = ipv4Settings
        
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        tunnelNetworkSettings.dnsSettings = dnsSettings
        tunnelNetworkSettings.mtu = 1500
        
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            guard let self = self else { return }
            
            var configJson = options?["configJson"] as? String
            if configJson == nil || configJson?.isEmpty == true {
                if let proto = self.protocolConfiguration as? NETunnelProviderProtocol {
                    configJson = proto.providerConfiguration?["configJson"] as? String
                }
            }
            
            #if canImport(Libbox)
            if let json = configJson, !json.isEmpty {
                do {
                    let platformInterface = ExtensionPlatformInterface(self)
                    let service = try LibboxNewService(json, platformInterface, nil)
                    self.boxService = service
                    try service.start()
                    NSLog("[PacketTunnel] Sing-box core successfully started!")
                } catch {
                    NSLog("[PacketTunnel] Sing-box core failed to start: \(error.localizedDescription)")
                }
            }
            #endif
            
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        #if canImport(Libbox)
        try? boxService?.close()
        boxService = nil
        #endif
        completionHandler()
    }
}
