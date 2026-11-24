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
    
    // Парсер ссылок vless://, vmess://, trojan://, ss://
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
            proto = .unknown
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
}

