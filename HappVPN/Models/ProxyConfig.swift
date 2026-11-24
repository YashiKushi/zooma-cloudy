import Foundation

enum ProxyProtocolType: String, Codable, CaseIterable {
    case vless = "VLESS"
    case vmess = "VMess"
    case trojan = "Trojan"
    case shadowsocks = "Shadowsocks"
    case wireguard = "WireGuard"
    case unknown = "Custom"
}

struct ProxyConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var server: String
    var port: Int
    var protocolType: ProxyProtocolType
    var rawUri: String
    var pingMs: Int?
    var isSelected: Bool = false
    
    // Парсер единичной ссылки vless://, vmess://, trojan://, ss://, wg://
    static func parse(urlString: String) -> ProxyConfig? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        
        let scheme = url.scheme?.lowercased() ?? ""
        let name = url.fragment?.removingPercentEncoding ?? "Сервер \(Int.random(in: 100...999))"
        let host = url.host ?? "0.0.0.0"
        let port = url.port ?? 443
        
        var proto: ProxyProtocolType = .unknown
        switch scheme {
        case "vless":
            proto = .vless
        case "vmess":
            proto = .vmess
        case "trojan":
            proto = .trojan
        case "ss":
            proto = .shadowsocks
        case "wg":
            proto = .wireguard
        default:
            return nil
        }
        
        return ProxyConfig(
            id: UUID(),
            name: name,
            server: host,
            port: port,
            protocolType: proto,
            rawUri: trimmed,
            pingMs: nil,
            isSelected: false
        )
    }
    
    // Парсинг текста подписки (Base64 или многострочный список серверов)
    static func parseSubscriptionContent(_ rawContent: String) -> [ProxyConfig] {
        var content = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Попытка раскодировать Base64 (стандарт для V2Ray/Xray/Happ подписок)
        if let decoded = decodeBase64(content) {
            content = decoded
        }
        
        let lines = content.components(separatedBy: .newlines)
        var configs: [ProxyConfig] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            if let config = ProxyConfig.parse(urlString: trimmedLine) {
                configs.append(config)
            }
        }
        
        return configs
    }
    
    // Безопасный декодер Base64 (включая URL-safe и восстановление паддинга)
    private static func decodeBase64(_ base64Str: String) -> String? {
        var str = base64Str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let rem = str.count % 4
        if rem > 0 {
            str.append(String(repeating: "=", count: 4 - rem))
        }
        
        guard let data = Data(base64Encoded: str, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
