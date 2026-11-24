import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @State private var showingAddSheet = false
    @State private var newConfigText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Верхний блок: статус и кнопка подключения в стиле Happ
                    VStack(spacing: 16) {
                        statusBadge
                        
                        connectButton
                        
                        if let selected = vpnManager.selectedServer {
                            Text("Выбран: \(selected.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Выберите конфигурацию ниже")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Список серверов
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Конфигурации / Прокси")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                showingAddSheet = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        List {
                            ForEach(vpnManager.servers) { server in
                                ServerRow(server: server)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        vpnManager.selectServer(server)
                                    }
                            }
                            .onDelete(perform: vpnManager.removeServer)
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .padding(.top, 10)
            }
            .navigationTitle("Happ VPN")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let clipboard = UIPasteboard.general.string {
                            vpnManager.addServer(from: clipboard)
                        }
                    }) {
                        Label("Вставить", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                addServerSheet
            }
        }
    }
    
    // Статус подключения
    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusTitle)
                .font(.footnote.weight(.semibold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }
    
    // Круглая кнопка включения
    private var connectButton: some View {
        Button(action: {
            vpnManager.toggleVPN()
        }) {
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 8)
                    .frame(width: 110, height: 110)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 90, height: 90)
                    .shadow(color: statusColor.opacity(0.4), radius: 10, x: 0, y: 5)
                
                Image(systemName: "power")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    // Модальное окно добавления узла
    private var addServerSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Ссылка на конфигурацию")) {
                    TextEditor(text: $newConfigText)
                        .frame(height: 120)
                    Text("Поддерживаются форматы: vless://, vmess://, trojan://, ss://")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Добавить сервер") {
                        vpnManager.addServer(from: newConfigText)
                        newConfigText = ""
                        showingAddSheet = false
                    }
                    .disabled(newConfigText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Новый сервер")
            .navigationBarItems(leading: Button("Отмена") {
                showingAddSheet = false
            })
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
        case .connected: return .green
        case .connecting, .disconnecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

struct ServerRow: View {
    let server: ProxyConfig
    
    var body: some View {
        HStack {
            Image(systemName: server.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(server.isSelected ? .blue : .gray)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.body.weight(.medium))
                
                HStack(spacing: 6) {
                    Text(server.protocolType.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text("\(server.server):\(server.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let ping = server.pingMs {
                Text("\(ping) ms")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(ping < 100 ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

