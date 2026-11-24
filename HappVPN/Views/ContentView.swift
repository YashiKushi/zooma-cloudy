import SwiftUI

enum ActiveAlert: Identifiable {
    case deleteSubscription
    case info(String)
    
    var id: String {
        switch self {
        case .deleteSubscription: return "delete_subscription"
        case .info(let msg): return msg
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showingAddSheet = false
    @State private var activeAlert: ActiveAlert?
    @State private var newConfigText = ""
    
    var body: some View {
        ZStack {
            // Глубокий премиальный фон в стиле Happ
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Шапка (Header)
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                
                // Прокручиваемый список
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Компактная карточка подключения (Hero Card)
                        heroConnectCard
                            .padding(.horizontal, 16)
                        
                        // Панель управления и заголовок
                        controlBarView
                            .padding(.horizontal, 16)
                        
                        // Список серверов
                        if vpnManager.servers.isEmpty {
                            emptyServersPlaceholder
                                .padding(.horizontal, 16)
                                .padding(.vertical, 24)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(vpnManager.servers) { server in
                                    ServerCardRow(server: server)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 34)
                        }
                    }
                }
            }
        }
        .onAppear {
            vpnManager.initializeIfNeeded()
        }
        .sheet(isPresented: $showingAddSheet) {
            addServerSheet
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .deleteSubscription:
                return Alert(
                    title: Text("Удалить подписку?"),
                    message: Text("Все 14+ серверов будут удалены из приложения."),
                    primaryButton: .destructive(Text("Удалить все")) {
                        withAnimation {
                            vpnManager.clearAllServers()
                        }
                    },
                    secondaryButton: .cancel(Text("Отмена"))
                )
            case .info(let message):
                return Alert(
                    title: Text("Информация"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onChange(of: vpnManager.alertMessage) { newMsg in
            if let msg = newMsg {
                activeAlert = .info(msg)
                vpnManager.alertMessage = nil
            }
        }
    }
    
    // Верхняя панель (Header)
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("zooma cloudy")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                // Быстрая вставка из буфера
                Button(action: {
                    if let clipboard = UIPasteboard.general.string {
                        vpnManager.addInput(clipboard)
                    }
                }) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                
                // Добавить вручную
                Button(action: {
                    showingAddSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
    
    // Компактная карточка подключения
    private var heroConnectCard: some View {
        VStack(spacing: 14) {
            // Круглая кнопка включения
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    vpnManager.toggleVPN()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.18), lineWidth: 10)
                        .frame(width: 106, height: 106)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 86, height: 86)
                        .shadow(color: statusColor.opacity(0.5), radius: 14, x: 0, y: 6)
                    
                    if vpnManager.status == .connecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 6)
            
            // Выбранный узел
            VStack(spacing: 5) {
                if let selected = vpnManager.selectedServer {
                    Text(selected.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                    
                    HStack(spacing: 8) {
                        Text(selected.protocolType.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.25))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                        
                        Text("\(selected.server):\(selected.port)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        if let ping = selected.pingMs {
                            Text("\(ping) ms")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(ping < 100 ? Color.green : Color.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                        }
                    }
                } else {
                    Text("Выберите сервер из списка")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.17))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Панель управления конфигурациями
    private var controlBarView: some View {
        HStack {
            Text("Конфигурации (\(vpnManager.servers.count))")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Кнопка замера всех
                Button(action: {
                    vpnManager.pingAllServers()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text(vpnManager.isPingingAll ? "Тест..." : "Пинг всех")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                }
                .disabled(vpnManager.servers.isEmpty || vpnManager.isPingingAll)
                
                // Кнопка удаления всей подписки
                Button(action: {
                    activeAlert = .deleteSubscription
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Очистить")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.14))
                    .cornerRadius(8)
                }
                .disabled(vpnManager.servers.isEmpty)
            }
        }
    }
    
    private var emptyServersPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Нет серверов")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("Вставьте ссылку на подписку через кнопку в правом верхнем углу.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.09, green: 0.10, blue: 0.14))
        )
    }
    
    private var addServerSheet: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Вставьте HTTPS ссылку на подписку:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $newConfigText)
                            .padding(10)
                            .frame(height: 130)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                        
                        Text("💡 После добавления приложение сразу импортирует все серверы и автоматически включит VPN.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.85))
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        if let clipboard = UIPasteboard.general.string {
                            newConfigText = clipboard
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Вставить из буфера обмена")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.14))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        vpnManager.addInput(newConfigText)
                        newConfigText = ""
                        showingAddSheet = false
                    }) {
                        Text("Импортировать и подключить")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(newConfigText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .cornerRadius(14)
                    }
                    .disabled(newConfigText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Новая подписка")
            .navigationBarItems(
                leading: Button("Отмена") {
                    showingAddSheet = false
                }.foregroundColor(.blue)
            )
        }
    }
    
    private var statusTitle: String {
        switch vpnManager.status {
        case .connected: return "ПОДКЛЮЧЕНО"
        case .connecting: return "ПОДКЛЮЧЕНИЕ..."
        case .disconnecting: return "ОТКЛЮЧЕНИЕ..."
        case .disconnected: return "ОТКЛЮЧЕНО"
        case .error(let msg): return "ОШИБКА: \(msg)"
        }
    }
    
    private var statusColor: Color {
        switch vpnManager.status {
        case .connected: return Color(red: 0.20, green: 0.85, blue: 0.45)
        case .connecting, .disconnecting: return Color(red: 1.0, green: 0.70, blue: 0.20)
        case .disconnected: return Color(red: 0.55, green: 0.58, blue: 0.65)
        case .error: return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
    }
}

// Карточка одного узла в списке
struct ServerCardRow: View {
    @EnvironmentObject var vpnManager: VPNManager
    let server: ProxyConfig
    
    var body: some View {
        HStack(spacing: 12) {
            // Выбор сервера
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vpnManager.selectServer(server)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: server.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(server.isSelected ? .blue : .gray.opacity(0.4))
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 6) {
                            Text(server.protocolType.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                            
                            Text("\(server.server):\(server.port)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Замер пинга
            if let ping = server.pingMs {
                Text("\(ping) ms")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(pingColor(ping))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)
            }
            
            // Кнопка удаления этого сервера
            Button(action: {
                withAnimation {
                    vpnManager.deleteServer(server)
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(server.isSelected ? Color(red: 0.14, green: 0.17, blue: 0.26) : Color(red: 0.10, green: 0.11, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(server.isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
    
    private func pingColor(_ ping: Int) -> Color {
        if ping < 100 {
            return Color(red: 0.25, green: 0.85, blue: 0.45)
        } else if ping < 250 {
            return Color(red: 1.0, green: 0.75, blue: 0.20)
        } else {
            return Color(red: 1.0, green: 0.40, blue: 0.40)
        }
    }
}
