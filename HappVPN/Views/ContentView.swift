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
            // Премиальный глубокий темный фон Happ
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Шапка приложения
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                
                // Основной скролл контента на весь экран
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Карточка подключения
                        heroConnectCard
                            .padding(.horizontal, 16)
                        
                        // Панель управления конфигурациями
                        controlBarView
                            .padding(.horizontal, 16)
                        
                        // Список всех конфигураций
                        if vpnManager.servers.isEmpty {
                            emptyServersPlaceholder
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(vpnManager.servers) { server in
                                    ServerCardRow(server: server)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
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
                    message: Text("Все серверы будут удалены из приложения."),
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
    
    // Шапка (Header)
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("zooma cloudy")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                // Вставить из буфера
                Button(action: {
                    if let clipboard = UIPasteboard.general.string {
                        vpnManager.addInput(clipboard)
                    }
                }) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
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
                        .frame(width: 38, height: 38)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
    
    // Компактная карточка подключения
    private var heroConnectCard: some View {
        VStack(spacing: 12) {
            // Кнопка питания
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    vpnManager.toggleVPN()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.18), lineWidth: 8)
                        .frame(width: 92, height: 92)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 74)
                        .shadow(color: statusColor.opacity(0.45), radius: 12, x: 0, y: 5)
                    
                    if vpnManager.status == .connecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 4)
            
            // Выбранный узел
            VStack(spacing: 4) {
                if let selected = vpnManager.selectedServer {
                    Text(selected.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                    
                    HStack(spacing: 6) {
                        Text(selected.protocolType.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.25))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        Text("\(selected.server):\(selected.port)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        if let ping = selected.pingMs {
                            Text("\(ping) ms")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(ping < 100 ? Color.green : Color.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(4)
                        }
                    }
                } else {
                    Text("Выберите сервер из списка ниже")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.17))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Панель управления и заголовок
    private var controlBarView: some View {
        HStack {
            Text("Конфигурации (\(vpnManager.servers.count))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 6) {
                // Кнопка замера всех
                Button(action: {
                    vpnManager.pingAllServers()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                        Text(vpnManager.isPingingAll ? "Тест..." : "Пинг всех")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.35))
                    .cornerRadius(8)
                }
                .disabled(vpnManager.servers.isEmpty || vpnManager.isPingingAll)
                
                // Кнопка удаления всей подписки
                Button(action: {
                    activeAlert = .deleteSubscription
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Очистить")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundColor(.red.opacity(0.95))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.18))
                    .cornerRadius(8)
                }
                .disabled(vpnManager.servers.isEmpty)
            }
        }
    }
    
    private var emptyServersPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 36))
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.09, green: 0.10, blue: 0.14))
        )
    }
    
    private var addServerSheet: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Вставьте HTTPS ссылку на подписку:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $newConfigText)
                            .padding(10)
                            .frame(height: 120)
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.blue.opacity(0.14))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        vpnManager.addInput(newConfigText)
                        newConfigText = ""
                        showingAddSheet = false
                    }) {
                        HStack {
                            if vpnManager.isLoadingSubscription {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 6)
                                Text("Импорт узлов...")
                            } else {
                                Image(systemName: "checkmark")
                                Text("Сохранить и подключить")
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(newConfigText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vpnManager.isLoadingSubscription)
                    
                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Новая подписка")
            .navigationBarItems(
                leading: Button("Отмена") {
                    showingAddSheet = false
                }
                .foregroundColor(.blue)
            )
        }
    }
    
    private var statusTitle: String {
        switch vpnManager.status {
        case .disconnected: return "ОТКЛЮЧЕНО"
        case .connecting: return "ПОДКЛЮЧЕНИЕ..."
        case .connected: return "ПОДКЛЮЧЕНО"
        case .disconnecting: return "ОТКЛЮЧЕНИЕ..."
        case .error: return "ОШИБКА"
        }
    }
    
    private var statusColor: Color {
        switch vpnManager.status {
        case .disconnected: return Color.gray
        case .connecting: return Color.orange
        case .connected: return Color(red: 0.18, green: 0.82, blue: 0.44)
        case .disconnecting: return Color.orange
        case .error: return Color.red
        }
    }
}

// Карточка одного узла в списке
struct ServerCardRow: View {
    @EnvironmentObject var vpnManager: VPNManager
    let server: ProxyConfig
    
    var body: some View {
        HStack(spacing: 10) {
            // Выбор сервера
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vpnManager.selectServer(server)
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: server.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(server.isSelected ? .blue : .gray.opacity(0.4))
                        .font(.system(size: 18))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(server.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 6) {
                            Text(server.protocolType.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                            
                            Text("\(server.server):\(server.port)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer(minLength: 4)
            
            // Замер пинга
            if let ping = server.pingMs {
                Text("\(ping) ms")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(pingColor(ping))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
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
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(server.isSelected ? Color(red: 0.14, green: 0.17, blue: 0.26) : Color(red: 0.10, green: 0.11, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
