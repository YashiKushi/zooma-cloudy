import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showingAddSheet = false
    @State private var newConfigText = ""
    @State private var isConnectingAnimation = false
    
    var body: some View {
        ZStack {
            // Глубокий темный фон в стиле Happ / Modern iOS
            Color(red: 0.06, green: 0.07, blue: 0.10)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Верхняя панель (Header)
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Главная карточка подключения (Hero Card)
                        heroConnectCard
                            .padding(.horizontal, 16)
                        
                        // Заголовок списка серверов
                        serversHeader
                            .padding(.horizontal, 20)
                        
                        // Список серверов в виде аккуратных карточек (без обрезания)
                        LazyVStack(spacing: 10) {
                            ForEach(vpnManager.servers) { server in
                                ServerCardView(server: server)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            vpnManager.selectServer(server)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
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
        .alert(isPresented: Binding<Bool>(
            get: { vpnManager.alertMessage != nil },
            set: { if !$0 { vpnManager.alertMessage = nil } }
        )) {
            Alert(
                title: Text("Информация"),
                message: Text(vpnManager.alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Верхний бар
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("zooma cloudy")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
            
            // Кнопка быстрой вставки из буфера
            Button(action: {
                if let clipboard = UIPasteboard.general.string {
                    vpnManager.addInput(clipboard)
                }
            }) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            
            // Кнопка добавления
            Button(action: {
                showingAddSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
    }
    
    // Карточка подключения
    private var heroConnectCard: some View {
        VStack(spacing: 18) {
            // Большая кнопка включения с неоновым кольцом
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    vpnManager.toggleVPN()
                }
            }) {
                ZStack {
                    // Внешнее пульсирующее свечение
                    Circle()
                        .stroke(statusColor.opacity(0.2), lineWidth: 14)
                        .frame(width: 130, height: 130)
                    
                    Circle()
                        .stroke(statusColor.opacity(0.4), lineWidth: 4)
                        .frame(width: 114, height: 114)
                    
                    // Центральная кнопка
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: statusColor.opacity(0.5), radius: 16, x: 0, y: 8)
                    
                    Image(systemName: "power")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 10)
            
            // Информация о выбранном узле
            VStack(spacing: 4) {
                if let selected = vpnManager.selectedServer {
                    Text(selected.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(selected.protocolType.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.25))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        
                        Text("\(selected.server):\(selected.port)")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Выберите сервер из списка ниже")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.12, green: 0.13, blue: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Заголовок блока серверов
    private var serversHeader: some View {
        HStack {
            Text("Конфигурации (\(vpnManager.servers.count))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            if vpnManager.isLoadingSubscription {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.9)
            }
        }
    }
    
    // Модальное окно добавления
    private var addServerSheet: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Вставьте ссылку на подписку или прокси:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $newConfigText)
                            .padding(12)
                            .frame(height: 140)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            .foregroundColor(.white)
                        
                        Text("Поддерживаются: HTTPS ссылки подписок, vless://, vmess://, trojan://, ss://")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.8))
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
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        vpnManager.addInput(newConfigText)
                        newConfigText = ""
                        showingAddSheet = false
                    }) {
                        Text("Импортировать")
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
                .padding(.top, 20)
            }
            .navigationTitle("Новая конфигурация")
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

// Карточка сервера в списке
struct ServerCardView: View {
    let server: ProxyConfig
    
    var body: some View {
        HStack(spacing: 14) {
            // Индикатор выбора (Радио-кнопка)
            Image(systemName: server.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(server.isSelected ? .blue : .gray.opacity(0.5))
                .font(.system(size: 22))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(server.protocolType.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text("\(server.server):\(server.port)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Бейдж пинга
            if let ping = server.pingMs {
                Text("\(ping) ms")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(ping < 100 ? Color.green : Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(server.isSelected ? Color(red: 0.14, green: 0.17, blue: 0.26) : Color(red: 0.11, green: 0.12, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(server.isSelected ? Color.blue.opacity(0.4) : Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}
