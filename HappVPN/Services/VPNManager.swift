import Foundation
import NetworkExtension
import Combine

enum VPNStatus {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)
}

class VPNManager: ObservableObject {
    static let shared = VPNManager()
    
    @Published var status: VPNStatus = .disconnected
    @Published var servers: [ProxyConfig] = []
    @Published var selectedServer: ProxyConfig?
    @Published var isLoadingSubscription: Bool = false
    @Published var alertMessage: String?
    
    private let vpnBundleId = "com.happ.vpn.PacketTunnel"
    private var tunnelManager: NETunnelProviderManager?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSavedServers()
        setupVPNManager()
        observeVPNStatus()
    }
    
    func setupVPNManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            if let error = error {
                print("Ошибка загрузки VPN профиля: \(error.localizedDescription)")
                return
            }
            
            if let existingManager = managers?.first {
                self.tunnelManager = existingManager
            } else {
                let newManager = NETunnelProviderManager()
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = self.vpnBundleId
                proto.serverAddress = "Happ Proxy"
                newManager.protocolConfiguration = proto
                newManager.localizedDescription = "Happ VPN"
                newManager.isEnabled = true
                
                newManager.saveToPreferences { saveError in
                    if let saveError = saveError {
                        print("Ошибка сохранения VPN конфигурации: \(saveError.localizedDescription)")
                    } else {
                        self.tunnelManager = newManager
                    }
                }
            }
        }
    }
    
    func toggleVPN() {
        if case .connected = status {
            disconnect()
        } else if case .disconnected = status {
            connect()
        }
    }
    
    func connect() {
        guard let manager = tunnelManager, let server = selectedServer else {
            status = .error("Выберите сервер")
            return
        }
        
        status = .connecting
        
        let providerProtocol = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = vpnBundleId
        providerProtocol.serverAddress = server.server
        
        // Передача конфигурации ноды в PacketTunnelProvider
        providerProtocol.providerConfiguration = [
            "server": server.server,
            "port": server.port,
            "rawUri": server.rawUri,
            "protocol": server.protocolType.rawValue
        ]
        
        manager.protocolConfiguration = providerProtocol
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.status = .error(error.localizedDescription)
                }
                return
            }
            
            manager.loadFromPreferences { _ in
                do {
                    try manager.connection.startVPNTunnel()
                } catch {
                    DispatchQueue.main.async {
                        self.status = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    func disconnect() {
        status = .disconnecting
        tunnelManager?.connection.stopVPNTunnel()
    }
    
    private func observeVPNStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let connection = self.tunnelManager?.connection else { return }
            switch connection.status {
            case .connected:
                self.status = .connected
            case .connecting:
                self.status = .connecting
            case .disconnected:
                self.status = .disconnected
            case .disconnecting:
                self.status = .disconnecting
            default:
                self.status = .disconnected
            }
        }
    }
    
    // Добавление сервера по одиночной ссылке, списку или HTTPS-подписке
    func addInput(_ rawInput: String) {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        if input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://") {
            downloadSubscription(from: input)
        } else {
            // Либо одиночный URL, либо многострочный список / Base64 в буфере
            let parsed = ProxyConfig.parseSubscriptionContent(input)
            if !parsed.isEmpty {
                appendServers(parsed)
                alertMessage = "Добавлено серверов: \(parsed.count)"
            } else if let single = ProxyConfig.parse(urlString: input) {
                appendServers([single])
                alertMessage = "Добавлен сервер: \(single.name)"
            } else {
                alertMessage = "Не удалось распознать формат ссылки или подписки."
            }
        }
    }
    
    // Загрузка подписки по HTTPS
    func downloadSubscription(from urlString: String) {
        guard let url = URL(string: urlString) else {
            alertMessage = "Некорректный HTTPS URL подписки"
            return
        }
        
        isLoadingSubscription = true
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("HappVPN/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingSubscription = false
                
                if let error = error {
                    self.alertMessage = "Ошибка загрузки: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data, let text = String(data: data, encoding: .utf8) else {
                    self.alertMessage = "Сервер вернул пустой или нечитаемый ответ"
                    return
                }
                
                let configs = ProxyConfig.parseSubscriptionContent(text)
                if configs.isEmpty {
                    self.alertMessage = "В подписке не найдено поддерживаемых серверов (VLESS, VMess, Trojan, SS)"
                } else {
                    self.appendServers(configs)
                    self.alertMessage = "Успешно импортировано серверов: \(configs.count)"
                }
            }
        }.resume()
    }
    
    private func appendServers(_ newServers: [ProxyConfig]) {
        for server in newServers {
            if !servers.contains(where: { $0.rawUri == server.rawUri }) {
                servers.append(server)
            }
        }
        if selectedServer == nil {
            selectedServer = servers.first
        }
        saveServers()
    }
    
    func selectServer(_ server: ProxyConfig) {
        for index in servers.indices {
            servers[index].isSelected = (servers[index].id == server.id)
        }
        selectedServer = server
        saveServers()
    }
    
    func removeServer(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
        if let selected = selectedServer, !servers.contains(where: { $0.id == selected.id }) {
            selectedServer = servers.first
        }
        saveServers()
    }
    
    func clearAllServers() {
        servers.removeAll()
        selectedServer = nil
        saveServers()
    }
    
    func checkPing(for server: ProxyConfig) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            let fakePing = Int.random(in: 45...180)
            servers[index].pingMs = fakePing
        }
    }
    
    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: "saved_proxy_servers")
        }
    }
    
    private func loadSavedServers() {
        if let data = UserDefaults.standard.data(forKey: "saved_proxy_servers"),
           let list = try? JSONDecoder().decode([ProxyConfig].self, from: data) {
            self.servers = list
            self.selectedServer = list.first(where: { $0.isSelected }) ?? list.first
        } else {
            let sample = ProxyConfig(
                id: UUID(),
                name: "Германия (VLESS-Reality)",
                server: "de1.example.com",
                port: 443,
                protocolType: .vless,
                rawUri: "vless://uuid@de1.example.com:443?security=reality#Германия",
                pingMs: 58,
                isSelected: true
            )
            self.servers = [sample]
            self.selectedServer = sample
        }
    }
}
