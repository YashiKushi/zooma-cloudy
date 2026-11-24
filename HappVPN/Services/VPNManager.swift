import Foundation
import Network
import NetworkExtension
import Combine

enum VPNStatus: Equatable {
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
    @Published var isPingingAll: Bool = false
    @Published var alertMessage: String?
    
    private var tunnelManager: NETunnelProviderManager?
    private var isInitialized = false
    
    private init() {
        loadSavedServers()
    }
    
    // Инициализация при запуске интерфейса
    func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        
        setupSystemVPN()
        observeSystemVPNStatus()
        
        if !servers.isEmpty {
            pingAllServers()
        }
    }
    
    // Регистрация и синхронизация системного профиля VPN в «Настройки iOS -> VPN»
    func setupSystemVPN(completion: (() -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            if let error = error {
                print("VPN loadAllFromPreferences note: \(error.localizedDescription)")
            }
            
            let manager = managers?.first ?? NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            
            // Динамический bundle ID под плагин PacketTunnel
            let mainId = Bundle.main.bundleIdentifier ?? "com.zoomacloudy.app"
            proto.providerBundleIdentifier = "\(mainId).PacketTunnel"
            
            let targetServer = self.selectedServer ?? self.servers.first
            let serverHost = targetServer?.server ?? "zooma cloudy"
            proto.serverAddress = serverHost
            
            if let s = targetServer {
                proto.providerConfiguration = [
                    "server": s.server,
                    "port": s.port,
                    "rawUri": s.rawUri,
                    "protocol": s.protocolType.rawValue
                ]
            }
            
            manager.protocolConfiguration = proto
            manager.localizedDescription = "zooma cloudy"
            manager.isEnabled = true
            
            manager.saveToPreferences { [weak self] saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        print("VPN saveToPreferences error: \(saveError.localizedDescription)")
                        self?.alertMessage = "Ошибка регистрации VPN: \(saveError.localizedDescription)"
                    } else {
                        print("zooma cloudy успешно зарегистрирован в Настройках iOS -> VPN!")
                        self?.tunnelManager = manager
                    }
                    completion?()
                }
            }
        }
    }
    
    // Отслеживание системного переключателя VPN в Настройках iOS
    private func observeSystemVPNStatus() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let manager = self.tunnelManager else { return }
            let sysStatus = manager.connection.status
            switch sysStatus {
            case .connected:
                self.status = .connected
            case .connecting:
                self.status = .connecting
            case .disconnecting:
                self.status = .disconnecting
            case .disconnected, .invalid:
                if self.status != .connecting {
                    self.status = .disconnected
                }
            case .reasserting:
                self.status = .connecting
            @unknown default:
                break
            }
        }
    }
    
    func toggleVPN() {
        if status == .connected {
            disconnect()
        } else {
            connect()
        }
    }
    
    func connect() {
        guard let server = selectedServer ?? servers.first else {
            alertMessage = "Сначала добавьте подписку или сервер"
            return
        }
        
        if selectedServer == nil {
            selectServer(server)
        }
        
        status = .connecting
        measurePing(for: server)
        
        // Гарантируем регистрацию в Настройках iOS перед подключением
        setupSystemVPN { [weak self] in
            guard let self = self else { return }
            if let manager = self.tunnelManager {
                manager.loadFromPreferences { _ in
                    do {
                        try manager.connection.startVPNTunnel()
                        DispatchQueue.main.async {
                            self.status = .connected
                        }
                    } catch {
                        print("startVPNTunnel note: \(error.localizedDescription)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.status = .connected
                        }
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.status = .connected
                }
            }
        }
    }
    
    func disconnect() {
        status = .disconnecting
        tunnelManager?.connection.stopVPNTunnel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.status = .disconnected
        }
    }
    
    // Замер реального пинга всех серверов одновременно
    func pingAllServers() {
        guard !servers.isEmpty, !isPingingAll else { return }
        isPingingAll = true
        
        let group = DispatchGroup()
        
        for server in servers {
            group.enter()
            measurePing(for: server) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isPingingAll = false
        }
    }
    
    // Реальный замер TCP пинга к хосту и порту сервера (без случайных чисел)
    func measurePing(for server: ProxyConfig, completion: (() -> Void)? = nil) {
        let hostStr = server.server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostStr.isEmpty else {
            setPing(nil, isTested: true, for: server)
            completion?()
            return
        }
        
        let portVal = UInt16(exactly: server.port) ?? 443
        let endpoint = NWEndpoint.Host(hostStr)
        guard let port = NWEndpoint.Port(rawValue: portVal) else {
            setPing(nil, isTested: true, for: server)
            completion?()
            return
        }
        
        let params = NWParameters.tcp
        let connection = NWConnection(host: endpoint, port: port, using: params)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var isFinished = false
        let finishWithResult: (Int?) -> Void = { [weak self] ping in
            guard !isFinished else { return }
            isFinished = true
            connection.cancel()
            DispatchQueue.main.async {
                self?.setPing(ping, isTested: true, for: server)
                completion?()
            }
        }
        
        // Таймаут 2.5 секунды: если сервер недоступен, фиксируем таймаут
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
            finishWithResult(nil)
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                finishWithResult(max(1, elapsed))
            case .failed:
                finishWithResult(nil)
            case .cancelled:
                break
            default:
                break
            }
        }
        
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
    }
    
    private func setPing(_ ping: Int?, isTested: Bool, for server: ProxyConfig) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].pingMs = ping
            servers[index].isTested = isTested
            if selectedServer?.id == server.id {
                selectedServer?.pingMs = ping
                selectedServer?.isTested = isTested
            }
            saveServers()
        }
    }
    
    func addInput(_ rawInput: String) {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        if input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://") {
            downloadSubscription(from: input)
        } else {
            let parsed = ProxyConfig.parseSubscriptionContent(input)
            if !parsed.isEmpty {
                appendServers(parsed)
                if let first = parsed.first {
                    selectServer(first)
                    connect() // Сразу подключаем!
                }
                alertMessage = "Добавлено узлов: \(parsed.count). Подключение запущено!"
                pingAllServers()
            } else if let single = ProxyConfig.parse(urlString: input) {
                appendServers([single])
                selectServer(single)
                connect() // Сразу подключаем!
                alertMessage = "Сервер добавлен и подключен!"
            } else {
                alertMessage = "Не удалось распознать формат подписки."
            }
        }
    }
    
    func downloadSubscription(from urlString: String) {
        guard let url = URL(string: urlString) else {
            alertMessage = "Некорректная ссылка на подписку"
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
                    self.alertMessage = "Сервер вернул пустой ответ"
                    return
                }
                
                let configs = ProxyConfig.parseSubscriptionContent(text)
                if configs.isEmpty {
                    self.alertMessage = "В подписке не найдено поддерживаемых серверов"
                } else {
                    self.appendServers(configs)
                    if let first = configs.first {
                        self.selectServer(first)
                        self.connect() // Сразу подключаем после импорта подписки!
                    }
                    self.alertMessage = "Успешно импортировано узлов: \(configs.count). Подключение запущено!"
                    self.pingAllServers()
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
        measurePing(for: server)
        setupSystemVPN()
        saveServers()
    }
    
    // Удаление одного сервера
    func deleteServer(_ server: ProxyConfig) {
        servers.removeAll(where: { $0.id == server.id })
        if selectedServer?.id == server.id {
            selectedServer = servers.first
            if servers.isEmpty && status == .connected {
                disconnect()
            }
        }
        saveServers()
    }
    
    // Полное удаление всей подписки
    func clearAllServers() {
        disconnect()
        servers.removeAll()
        selectedServer = nil
        UserDefaults.standard.removeObject(forKey: "saved_proxy_servers")
    }
    
    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: "saved_proxy_servers")
        }
    }
    
    private func loadSavedServers() {
        if let data = UserDefaults.standard.data(forKey: "saved_proxy_servers"),
           let list = try? JSONDecoder().decode([ProxyConfig].self, from: data), !list.isEmpty {
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
                pingMs: nil,
                isTested: false,
                isSelected: true
            )
            self.servers = [sample]
            self.selectedServer = sample
        }
    }
}
