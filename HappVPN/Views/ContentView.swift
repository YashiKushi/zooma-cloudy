import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var newConfigText = ""
    
    var body: some View {
        ZStack {
            // Глубокий темный фон в стиле Happ / Modern iOS
            Color(red: 0.05, green: 0.06, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Шапка приложения (Header)
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                
                // Прокручиваемый контент
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Главная карточка подключения (Hero Card)
                        heroConnectCard
                            .padding(.horizontal, 16)
                        
                        // Панель управления списком конфигураций
                        controlBarView
                            .padding(.horizontal, 16)
                        
                        // Список серверов (аккуратные карточки, ничего не обрезается)
                        if vpnManager.servers.isEmpty {
                            emptyServersPlaceholder
                                .padding(.horizontal, 16)
                                .padding(.vertical, 30)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(vpnManager.servers) { server in
                                    ServerCardRow(server: server)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
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
        .alert("Удалить всю подписку?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить все", role: .destructive) {
                withAnimation {
                    vpnManager.clearAllServers()
                }
            }
        } message: {
            Text("Все сохраненные серверы будут удалены из приложения.")
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
    
    // Верхняя панель (Header)
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("zooma cloudy")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
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
                // Кнопка быстрого пинга всех серверов
                Button(action: {
                    vpnManager.pingAllServers()
                }) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16))
                        .foregroundColor(vpnManager.isPingingAll ? .orange : .white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .disabled(vpnManager.servers.isEmpty || vpnManager.isPingingAll)
                
                // Кнопка вставки из буфера обмена
                Button(action: {
                    if let clipboard = UIPasteboard.general.string {
                        vpnManager.addInput(clipboard)
                    }
                }) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                
                // Кнопка добавить вручную
                Button(action: {
                    showingAddSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
    
    // Главная карточка подключения (Hero Card)
    private var heroConnectCard: some View {
        VStack(spacing: 16) {
            // Большая кнопка подключения
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    vpnManager.toggleVPN()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.18), lineWidth: 16)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .stroke(statusColor.opacity(0.35), lineWidth: 4)
                        .frame(width: 122, height: 122)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)
                        .shadow(color: statusColor.opacity(0.55), radius: 18, x: 0, y: 8)
                    
                    if vpnManager.status == .connecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.4)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 8)
            
            // Информация о текущем подключении
            VStack(spacing: 6) {
                if let selected = vpnManager.selectedServer {
                    Text(selected.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        Text(selected.protocolType.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.25))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        
                        Text("\(selected.server):\(selected.port)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        if let ping = selected.pingMs {
                            Text("\(ping) ms")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(ping < 100 ? Color.green : Color.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                } else {
                    Text("Выберите сервер из списка")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.17))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // Панель управления серверами
    private var controlBarView: some View {
        HStack {
            Text("Конфигурации (\(vpnManager.servers.count))")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Кнопка замера всех серверов
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
                    .background(Color.blue.opacity(0.25))
                    .cornerRadius(8)
                }
                .disabled(vpnManager.servers.isEmpty || vpnManager.isPingingAll)
                
                // Кнопка удаления всей подписки
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(8)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                }
                .disabled(vpnManager.servers.isEmpty)
            }
        }
    }
    
    // Заглушка если список пуст
    private var emptyServersPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.5))
            Text("Нет конфигураций")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("Вставьте ссылку на подписку через кнопку в правом верхнем углу.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.10, green: 0.11, blue: 0.15))
        )
    }
    
    // Модальное окно добавления
    private var addServerSheet: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Вставьте HTTPS подписку или прокси-ссылку:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $newConfigText)
                            .padding(12)
                            .frame(height: 140)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            .foregroundColor(.white)
                        
                        Text("💡 При вставке подписки приложение сразу сохранит все узлы и автоматически подключится к первому серверу.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.9))
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
                .padding(.top, 20)
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

// Карточка одного сервера с полным текстом и кнопкой удаления
struct ServerCardRow: View {
    @EnvironmentObject var vpnManager: VPNManager
    let server: ProxyConfig
    
    var body: some View {
        HStack(spacing: 12) {
            // Кнопка выбора сервера
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
                            .font(.system(size: 15, weight: .semibold))
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
            
            // Бейдж пинга
            if let ping = server.pingMs {
                Text("\(ping) ms")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(pingColor(ping))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
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
