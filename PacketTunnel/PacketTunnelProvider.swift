import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Конфигурация виртуального сетевого интерфейса (TUN)
        let tunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        
        // IPv4 параметры
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        tunnelNetworkSettings.ipv4Settings = ipv4Settings
        
        // DNS серверы (Cloudflare & Google)
        let dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        tunnelNetworkSettings.dnsSettings = dnsSettings
        
        // MTU
        tunnelNetworkSettings.mtu = 1500
        
        // Применяем настройки сети
        setTunnelNetworkSettings(tunnelNetworkSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            // В продакшн сборках здесь запускается Go-ядро (Xray-core / Sing-box core)
            // через Libbox.xcframework или XrayKit.xcframework:
            // LibboxStart(configJson, self?.packetFlow)
            
            self?.startPacketForwarding()
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Остановка Xray ядра и очистка ресурсов
        completionHandler()
    }
    
    private func startPacketForwarding() {
        packetFlow.readPackets { [weak self] (packets, protocols) in
            // Чтение пакетов из tun интерфейса и отправка в прокси-туннель
            self?.startPacketForwarding()
        }
    }
}

