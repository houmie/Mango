import Foundation

extension MGConfiguration {
    
    struct URLComponents {
        
        let protocolType: MGConfiguration.ProtocolType
        let user: String
        let host: String
        let port: Int
        let queryMapping: [String: String]
        let network: MGConfiguration.Transport
        let security: MGConfiguration.Security
        let descriptive: String
        
        init(urlString: String) throws {
            guard let components = Foundation.URLComponents(string: urlString),
                  let protocolType = components.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) else {
                throw NSError.newError("Protocol link parsing failed")
            }
            guard protocolType == .vless || protocolType == .vmess else {
                throw NSError.newError("Not supported yet \(protocolType.description) protocol analysis")
            }
            guard let user = components.user, !user.isEmpty else {
                throw NSError.newError("User does not exist")
            }
            guard let host = components.host, !host.isEmpty else {
                throw NSError.newError("The server domain name or address does not exist")
            }
            guard let port = components.port, (1...65535).contains(port) else {
                throw NSError.newError("The port number of the server is invalid")
            }
            let mapping = (components.queryItems ?? []).reduce(into: [String: String](), { result, item in
                result[item.name] = item.value
            })
            let network: MGConfiguration.Transport
            if let value = mapping["type"], !value.isEmpty {
                if let value = MGConfiguration.Transport(rawValue: value) {
                    network = value
                } else {
                    throw NSError.newError("Unknown transport")
                }
            } else {
                throw NSError.newError("Transport method cannot be empty")
            }
            let security: MGConfiguration.Security
            if let value = mapping["security"] {
                if value.isEmpty {
                    throw NSError.newError("Transport Security cannot be empty")
                } else {
                    if let value = MGConfiguration.Security(rawValue: value) {
                        security = value
                    } else {
                        throw NSError.newError("Unknown transport security method")
                    }
                }
            } else {
                security = .none
            }
            self.protocolType = protocolType
            self.user = user
            self.host = host
            self.port = port
            self.network = network
            self.security = security
            self.queryMapping = mapping
            self.descriptive = components.fragment ?? ""
        }
    }
}


protocol MGConfigurationParserProtocol {
    
    associatedtype Output
    
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Output>
}

extension MGConfiguration.VLESS: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.protocolType == .vless else {
            return .none
        }
        var vless = MGConfiguration.VLESS()
        vless.address = components.host
        vless.port = components.port
        vless.users[0].id = components.user
        if let value = components.queryMapping["encryption"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) The encryption algorithm exists but is empty")
            } else {
                if value == "none" {
                    vless.users[0].encryption = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) Unsupported encryption algorithm: \(value)")
                }
            }
        } else {
            vless.users[0].encryption = "none"
        }
        if let value = components.queryMapping["flow"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) flow control cannot be empty")
            } else {
                if let value = MGConfiguration.Flow(rawValue: value) {
                    vless.users[0].flow = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) flow control not supported: \(value)")
                }
            }
        } else {
            vless.users[0].flow = .none
        }
        return vless
    }
}

extension MGConfiguration.VMess: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.protocolType == .vmess else {
            return .none
        }
        var vmess = MGConfiguration.VMess()
        vmess.address = components.host
        vmess.port = components.port
        vmess.users[0].id = components.user
        if let value = components.queryMapping["encryption"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) Encryption algorithm cannot be empty")
            } else {
                if let value = MGConfiguration.Encryption(rawValue: value) {
                    vmess.users[0].security = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) Unsupported encryption algorithm: \(value)")
                }
            }
        } else {
            vmess.users[0].security = .auto
        }
        return vmess
    }
}

extension MGConfiguration.Trojan: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        return .none
    }
}

extension MGConfiguration.Shadowsocks: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        return .none
    }
}

extension MGConfiguration.StreamSettings.TCP: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.network == .tcp else {
            return .none
        }
        return MGConfiguration.StreamSettings.TCP()
    }
}

extension MGConfiguration.StreamSettings.KCP: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.network == .kcp else {
            return .none
        }
        var kcp = MGConfiguration.StreamSettings.KCP()
        if let value = components.queryMapping["headerType"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) headerType can not be empty")
            } else {
                if let value = MGConfiguration.HeaderType(rawValue: value) {
                    kcp.header.type = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) headerType unsupported type: \(value)")
                }
            }
        } else {
            kcp.header.type = .none
        }
        if let value = components.queryMapping["seed"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) seed can not be empty")
            } else {
                kcp.seed = value
            }
        } else {
            kcp.seed = ""
        }
        return kcp
    }
}

extension MGConfiguration.StreamSettings.WS: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.network == .ws else {
            return .none
        }
        var ws = MGConfiguration.StreamSettings.WS()
        if let value = components.queryMapping["host"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) host can not be empty")
            } else {
                ws.headers["Host"] = value
            }
        } else {
            ws.headers["Host"] = components.host
        }
        if let value = components.queryMapping["path"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) path can not be empty")
            } else {
                ws.path = value
            }
        } else {
            ws.path = "/"
        }
        return ws
    }
}

extension MGConfiguration.StreamSettings.HTTP: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.network == .http else {
            return .none
        }
        var http = MGConfiguration.StreamSettings.HTTP()
        if let value = components.queryMapping["host"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) host can not be empty")
            } else {
                http.host = [value]
            }
        } else {
            http.host = [components.host]
        }
        if let value = components.queryMapping["path"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) path can not be empty")
            } else {
                http.path = value
            }
        } else {
            http.path = "/"
        }
        return http
    }
}

extension MGConfiguration.StreamSettings.QUIC: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.network == .quic else {
            return .none
        }
        var quic = MGConfiguration.StreamSettings.QUIC()
        if let value = components.queryMapping["quicSecurity"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) quicSecurity can not be empty")
            } else {
                if let value = MGConfiguration.Encryption.init(rawValue: value) {
                    quic.security = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) quicSecurity unsupported type: \(value)")
                }
            }
        } else {
            quic.security = .none
        }
        if let value = components.queryMapping["key"] {
            if quic.security == .none {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) quicSecurity for none, key cannot appear")
            }
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) key can not be empty")
            } else {
                quic.key = value
            }
        } else {
            quic.key = ""
        }
        if let value = components.queryMapping["headerType"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) headerType can not be empty")
            } else {
                if let value = MGConfiguration.HeaderType(rawValue: value) {
                    quic.header.type = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) headerType unsupported type: \(value)")
                }
            }
        } else {
            quic.header.type = .none
        }
        return quic
    }
}

extension MGConfiguration.StreamSettings.GRPC: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.network == .grpc else {
            return .none
        }
        var grpc = MGConfiguration.StreamSettings.GRPC()
        if let value = components.queryMapping["serviceName"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) serviceName can not be empty")
            } else {
                grpc.serviceName = value
            }
        } else {
            grpc.serviceName = ""
        }
        if let value = components.queryMapping["mode"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) \(components.network.rawValue) mode can not be empty")
            } else {
                grpc.multiMode = value == "multi"
            }
        } else {
            grpc.multiMode = false
        }
        return grpc
    }
}

extension MGConfiguration.StreamSettings.TLS: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.security == .tls else {
            return .none
        }
        var tls = MGConfiguration.StreamSettings.TLS()
        if let value = components.queryMapping["sni"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) TLS sni can not be empty")
            } else {
                tls.serverName = value
            }
        } else {
            tls.serverName = components.host
        }
        if let value = components.queryMapping["fp"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) TLS fp can not be empty")
            } else {
                if let value = MGConfiguration.Fingerprint(rawValue: value) {
                    tls.fingerprint = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) TLS fingerprint not supported: \(value)")
                }
            }
        } else {
            tls.fingerprint = .chrome
        }
        if let value = components.queryMapping["alpn"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) TLS alpn can not be empty")
            } else {
                tls.alpn = value.components(separatedBy: ",").compactMap(MGConfiguration.ALPN.init(rawValue:))
            }
        } else {
            tls.alpn = MGConfiguration.ALPN.allCases
        }
        return tls
    }
}

extension MGConfiguration.StreamSettings.Reality: MGConfigurationParserProtocol {
        
    static func parse(with components: MGConfiguration.URLComponents) throws -> Optional<Self> {
        guard components.security == .reality else {
            return .none
        }
        var reality = MGConfiguration.StreamSettings.Reality()
        if let value = components.queryMapping["pbk"], !value.isEmpty {
            reality.publicKey = value
        } else {
            throw NSError.newError("\(components.protocolType.description) Reality pbk illegal")
        }
        reality.shortId = components.queryMapping["sid"] ?? ""
        reality.spiderX = components.queryMapping["spx"] ?? ""
        if let value = components.queryMapping["sni"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) Reality sni can not be empty")
            } else {
                reality.serverName = value
            }
        } else {
            reality.serverName = components.host
        }
        if let value = components.queryMapping["fp"] {
            if value.isEmpty {
                throw NSError.newError("\(components.protocolType.description) Reality fp can not be empty")
            } else {
                if let value = MGConfiguration.Fingerprint(rawValue: value) {
                    reality.fingerprint = value
                } else {
                    throw NSError.newError("\(components.protocolType.description) Reality fingerprint not supported: \(value)")
                }
            }
        } else {
            reality.fingerprint = .chrome
        }
        return reality
    }
}

extension MGConfiguration.Model {
    
    init(components: MGConfiguration.URLComponents) throws {
        self.protocolType   = components.protocolType
        self.vless          = try MGConfiguration.VLESS.parse(with: components)
        self.vmess          = try MGConfiguration.VMess.parse(with: components)
        self.trojan         = try MGConfiguration.Trojan.parse(with: components)
        self.shadowsocks    = try MGConfiguration.Shadowsocks.parse(with: components)
        self.network        = components.network
        self.tcp            = try MGConfiguration.StreamSettings.TCP.parse(with: components)
        self.kcp            = try MGConfiguration.StreamSettings.KCP.parse(with: components)
        self.ws             = try MGConfiguration.StreamSettings.WS.parse(with: components)
        self.http           = try MGConfiguration.StreamSettings.HTTP.parse(with: components)
        self.quic           = try MGConfiguration.StreamSettings.QUIC.parse(with: components)
        self.grpc           = try MGConfiguration.StreamSettings.GRPC.parse(with: components)
        self.security       = components.security
        self.tls            = try MGConfiguration.StreamSettings.TLS.parse(with: components)
        self.reality        = try MGConfiguration.StreamSettings.Reality.parse(with: components)
    }
}
