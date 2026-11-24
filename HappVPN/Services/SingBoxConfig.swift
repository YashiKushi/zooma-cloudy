import Foundation

struct SingBoxConfig {
    static func generate(from proxy: ProxyConfig) -> String {
        let uri = proxy.rawUri
        guard let url = URL(string: uri) else {
            return generateFallbackConfig(host: proxy.server, port: proxy.port)
        }
        
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host ?? proxy.server
        let port = url.port ?? proxy.port
        let uuid = url.user ?? ""
        
        var queryItems: [String: String] = [:]
        if let components = URLComponents(string: uri), let items = components.queryItems {
            for item in items {
                queryItems[item.name.lowercased()] = item.value ?? ""
            }
        }
        
        let security = queryItems["security"] ?? "none"
        let sni = queryItems["sni"] ?? host
        let pbk = queryItems["pbk"] ?? ""
        let sid = queryItems["sid"] ?? ""
        let flow = queryItems["flow"] ?? ""
        let type = queryItems["type"] ?? "tcp"
        let path = queryItems["path"] ?? "/"
        let serviceName = queryItems["servicename"] ?? ""
        
        var outboundDict: [String: Any] = [:]
        
        switch scheme {
        case "vless":
            var vless: [String: Any] = [
                "type": "vless",
                "tag": "proxy",
                "server": host,
                "server_port": port,
                "uuid": uuid
            ]
            if !flow.isEmpty {
                vless["flow"] = flow
            }
            if security == "reality" {
                vless["tls"] = [
                    "enabled": true,
                    "server_name": sni,
                    "utls": [
                        "enabled": true,
                        "fingerprint": "chrome"
                    ],
                    "reality": [
                        "enabled": true,
                        "public_key": pbk,
                        "short_id": sid
                    ]
                ]
            } else if security == "tls" {
                vless["tls"] = [
                    "enabled": true,
                    "server_name": sni,
                    "utls": [
                        "enabled": true,
                        "fingerprint": "chrome"
                    ]
                ]
            }
            if type == "ws" {
                vless["transport"] = [
                    "type": "ws",
                    "path": path,
                    "headers": ["Host": sni]
                ]
            } else if type == "grpc" {
                vless["transport"] = [
                    "type": "grpc",
                    "service_name": serviceName
                ]
            }
            outboundDict = vless
            
        case "trojan":
            var trojan: [String: Any] = [
                "type": "trojan",
                "tag": "proxy",
                "server": host,
                "server_port": port,
                "password": uuid.isEmpty ? (url.password ?? "") : uuid,
                "tls": [
                    "enabled": true,
                    "server_name": sni
                ]
            ]
            if type == "ws" {
                trojan["transport"] = [
                    "type": "ws",
                    "path": path,
                    "headers": ["Host": sni]
                ]
            }
            outboundDict = trojan
            
        case "ss":
            // shadowsocks
            outboundDict = [
                "type": "shadowsocks",
                "tag": "proxy",
                "server": host,
                "server_port": port,
                "method": "aes-128-gcm",
                "password": uuid
            ]
            
        default:
            return generateFallbackConfig(host: host, port: port)
        }
        
        let rootConfig: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true
            ],
            "dns": [
                "servers": [
                    [
                        "tag": "dns-remote",
                        "address": "tcp://1.1.1.1",
                        "detour": "proxy"
                    ],
                    [
                        "tag": "dns-direct",
                        "address": "local",
                        "detour": "direct"
                    ]
                ],
                "rules": [
                    [
                        "outbound": "any",
                        "server": "dns-direct"
                    ]
                ]
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "inet4_address": "172.19.0.1/30",
                    "auto_route": true,
                    "strict_route": true,
                    "sniff": true
                ]
            ],
            "outbounds": [
                outboundDict,
                [
                    "type": "direct",
                    "tag": "direct"
                ]
            ],
            "route": [
                "auto_detect_interface": true,
                "final": "proxy"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: rootConfig, options: [.prettyPrinted]),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            return jsonStr
        }
        
        return generateFallbackConfig(host: host, port: port)
    }
    
    private static func generateFallbackConfig(host: String, port: Int) -> String {
        return """
        {
          "log": { "level": "info" },
          "inbounds": [
            {
              "type": "tun",
              "tag": "tun-in",
              "inet4_address": "172.19.0.1/30",
              "auto_route": true
            }
          ],
          "outbounds": [
            {
              "type": "direct",
              "tag": "direct"
            }
          ]
        }
        """
    }
}
