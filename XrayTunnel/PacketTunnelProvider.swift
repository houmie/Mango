import NetworkExtension
import XrayKit
import Tun2SocksKit
import os

extension MGConstant {
    static let cachesDirectory = URL(filePath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])
}

class PacketTunnelProvider: NEPacketTunnelProvider, XrayLoggerProtocol {
    
    private let logger = Logger(subsystem: "com.venuscloud.Mango.XrayTunnel", category: "Core")
    
    override func startTunnel(options: [String : NSObject]? = nil) async throws {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        settings.mtu = 9000
        let netowrk = MGNetworkModel.current
        settings.ipv4Settings = {
            let settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
            settings.includedRoutes = [NEIPv4Route.default()]
            if netowrk.hideVPNIcon {
                settings.excludedRoutes = [NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "255.0.0.0")]
            }
            return settings
        }()
        settings.ipv6Settings = {
            guard netowrk.ipv6Enabled else {
                return nil
            }
            let settings = NEIPv6Settings(addresses: ["fd6e:a81b:704f:1211::1"], networkPrefixLengths: [64])
            settings.includedRoutes = [NEIPv6Route.default()]
            if netowrk.hideVPNIcon {
                settings.excludedRoutes = [NEIPv6Route(destinationAddress: "::", networkPrefixLength: 128)]
            }
            return settings
        }()
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
        try await self.setTunnelNetworkSettings(settings)
        do {
            try self.startXray(inboundPort: netowrk.inboundPort)
            try self.startSocks5Tunnel(serverPort: netowrk.inboundPort)
        } catch {
            MGNotification.send(title: "", subtitle: "", body: error.localizedDescription)
            throw error
        }
    }
    
    private func startXray(inboundPort: Int) throws {
        guard let id = UserDefaults.shared.string(forKey: MGConfiguration.currentStoreKey), !id.isEmpty else {
            throw NSError.newError("Currently no valid configuration")
        }
        let configuration = try MGConfiguration(uuidString: id)
        let data = try configuration.loadData(inboundPort: inboundPort)
        let configurationFilePath = MGConstant.cachesDirectory.appending(component: "config.json").path(percentEncoded: false)
        os_log("[CONFIG] %{public}@", String(data: data, encoding: .utf8) ?? "NULL")
        guard FileManager.default.createFile(atPath: configurationFilePath, contents: data) else {
            throw NSError.newError("Xray Failed to write configuration file")
        }
        let log = MGLogModel.current
        XraySetupLogger(self, log.accessLogEnabled, log.dnsLogEnabled, log.errorLogSeverity.rawValue)
        XraySetenv("XRAY_LOCATION_CONFIG", MGConstant.cachesDirectory.path(percentEncoded: false), nil)
        XraySetenv("XRAY_LOCATION_ASSET", MGConstant.assetDirectory.path(percentEncoded: false), nil)
        var error: NSError? = nil
        XrayRun(&error)
        if let error = error {
            os_log("[ERROR] %{public}@", error.localizedDescription as NSString)
        }
        try error.flatMap { throw $0 }
    }
    
    private func startSocks5Tunnel(serverPort port: Int) throws {
        let config = """
        tunnel:
          mtu: 9000
        socks5:
          port: \(port)
          address: ::1
          udp: 'udp'
        misc:
          task-stack-size: 20480
          connect-timeout: 5000
          read-write-timeout: 60000
          log-file: stderr
          log-level: error
          limit-nofile: 65535
        """
        let configurationFilePath = MGConstant.cachesDirectory.appending(component: "config.yml").path(percentEncoded: false)
        guard FileManager.default.createFile(atPath: configurationFilePath, contents: config.data(using: .utf8)!) else {
            throw NSError.newError("Tunnel Failed to write configuration file")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            NSLog("HEV_SOCKS5_TUNNEL_MAIN: \(Socks5Tunnel.run(withConfig: configurationFilePath))")
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason) async {
        let message: String
        switch reason {
        case .none:
            message = "No specific reason."
        case .userInitiated:
            message = "The user stopped the provider."
        case .providerFailed:
            message = "The provider failed."
        case .noNetworkAvailable:
            message = "There is no network connectivity."
        case .unrecoverableNetworkChange:
            message = "The device attached to a new network."
        case .providerDisabled:
            message = "The provider was disabled."
        case .authenticationCanceled:
            message = "The authentication process was cancelled."
        case .configurationFailed:
            message = "The provider could not be configured."
        case .idleTimeout:
            message = "The provider was idle for too long."
        case .configurationDisabled:
            message = "The associated configuration was disabled."
        case .configurationRemoved:
            message = "The associated configuration was deleted."
        case .superceded:
            message = "A high-priority configuration was started."
        case .userLogout:
            message = "The user logged out."
        case .userSwitch:
            message = "The active user changed."
        case .connectionFailed:
            message = "Failed to establish connection."
        case .sleep:
            message = "The device went to sleep and disconnectOnSleep is enabled in the configuration."
        case .appUpdate:
            message = "The NEProvider is being updated."
        @unknown default:
            return
        }
        MGNotification.send(title: "", subtitle: "", body: message)
    }
    
    func onAccessLog(_ message: String?) {
        message.flatMap { logger.log("\($0, privacy: .public)") }
    }
    
    func onDNSLog(_ message: String?) {
        message.flatMap { logger.log("\($0, privacy: .public)") }
    }
    
    func onGeneralMessage(_ severity: Int, message: String?) {
        let level = MGLogModel.Severity(rawValue: severity) ?? .none
        guard let message = message, !message.isEmpty else {
            return
        }
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .none:
            break
        }
    }
}

extension MGConfiguration {
    
    func loadData(inboundPort: Int) throws -> Data {
        let file = MGConstant.configDirectory.appending(component: "\(self.id)/config.json")
        let data = try Data(contentsOf: file)
        if self.attributes.source.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) == nil {
            return data
        } else {
            let model = try JSONDecoder().decode(MGConfiguration.Model.self, from: data)
            return try model.buildConfigurationData(inboundPort: inboundPort)
        }
    }
}

extension MGConfiguration.Model {
    
    func buildConfigurationData(inboundPort: Int) throws -> Data {
        var configuration: [String: Any] = [:]
        configuration["inbounds"] = [try self.buildInbound(inboundPort: inboundPort)]
        var route = MGRouteModel.current
        configuration["routing"] = try route.build()
        configuration["outbounds"] = [
            try self.buildProxyOutbound(),
            try self.buildDirectOutbound(),
            try self.buildBlockOutbound()
        ]
        return try JSONSerialization.data(withJSONObject: configuration, options: .sortedKeys)
    }
    
    private func buildInbound(inboundPort: Int) throws -> Any {
        var inbound: [String: Any] = [:]
        inbound["listen"] = "[::1]"
        inbound["protocol"] = "socks"
        inbound["settings"] = [
            "udp": true,
            "auth": "noauth"
        ]
        inbound["tag"] = "socks-in"
        inbound["port"] = inboundPort
        inbound["sniffing"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(MGSniffingModel.current))
        return inbound
    }
    
    private func buildProxyOutbound() throws -> Any {
        var proxy: [String: Any] = [:]
        proxy["tag"] = "proxy"
        proxy["protocol"] = self.protocolType.rawValue
        switch self.protocolType {
        case .vless:
            guard let vless = self.vless else {
                throw NSError.newError("\(self.protocolType.description) build failed")
            }
            proxy["settings"] = ["vnext": [try JSONSerialization.jsonObject(with: try JSONEncoder().encode(vless))]]
        case .vmess:
            guard let vmess = self.vmess else {
                throw NSError.newError("\(self.protocolType.description) build failed")
            }
            proxy["settings"] = ["vnext": [try JSONSerialization.jsonObject(with: try JSONEncoder().encode(vmess))]]
        case .trojan:
            guard let trojan = self.trojan else {
                throw NSError.newError("\(self.protocolType.description) build failed")
            }
            proxy["settings"] = ["servers": [try JSONSerialization.jsonObject(with: try JSONEncoder().encode(trojan))]]
        case .shadowsocks:
            guard let shadowsocks = self.shadowsocks else {
                throw NSError.newError("\(self.protocolType.description) build failed")
            }
            proxy["settings"] = ["servers": [try JSONSerialization.jsonObject(with: try JSONEncoder().encode(shadowsocks))]]
        }
        var streamSettings: [String: Any] = [:]
        streamSettings["network"] = self.network.rawValue
        switch self.network {
        case .tcp:
            guard let tcp = self.tcp else {
                throw NSError.newError("\(self.network.description) build failed")
            }
            streamSettings["tcpSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(tcp))
        case .kcp:
            guard let kcp = self.kcp else {
                throw NSError.newError("\(self.network.description) build failed")
            }
            streamSettings["kcpSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(kcp))
        case .ws:
            guard let ws = self.ws else {
                throw NSError.newError("\(self.network.description) build failed")
            }
            streamSettings["wsSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(ws))
        case .http:
            guard let http = self.http else {
                throw NSError.newError("\(self.network.description) build failed")
            }
            streamSettings["httpSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(http))
        case .quic:
            guard let quic = self.quic else {
                throw NSError.newError("\(self.network.description) build failed")
            }
            streamSettings["quicSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(quic))
        case .grpc:
            guard let grpc = self.grpc else {
                throw NSError.newError("\(self.network.description) build failed")
            }
            streamSettings["grpcSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(grpc))
        }
        streamSettings["security"] = self.security.rawValue
        switch self.security {
        case .none:
            break
        case .tls:
            guard let tls = self.tls else {
                throw NSError.newError("\(self.security.description) build failed")
            }
            streamSettings["tlsSettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(tls))
        case .reality:
            guard let reality = self.reality else {
                throw NSError.newError("\(self.security.description) build failed")
            }
            streamSettings["realitySettings"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(reality))
        }
        proxy["streamSettings"] = streamSettings
        return proxy
    }
    
    private func buildDirectOutbound() throws -> Any {
        return [
            "tag": "direct",
            "protocol": "freedom"
        ]
    }
    
    private func buildBlockOutbound() throws -> Any {
        return [
            "tag": "block",
            "protocol": "blackhole"
        ]
    }
}

extension MGSniffingModel {
    
    func build() throws -> Any {
        var sniffing: [String: Any] = [:]
        sniffing["enabled"] = self.enabled
//        sniffing["destOverride"] = {
//            var destOverride: [String] = []
//            if self.httpEnabled {
//                destOverride.append("http")
//            }
//            if self.tlsEnabled {
//                destOverride.append("tls")
//            }
//            if self.quicEnabled {
//                destOverride.append("quic")
//            }
//            if self.fakednsEnabled {
//                destOverride.append("fakedns")
//            }
//            if destOverride.count == 4 {
//                destOverride = ["fakedns+others"]
//            }
//            return destOverride
//        }()
        sniffing["metadataOnly"] = self.metadataOnly
        sniffing["domainsExcluded"] = self.excludedDomains
        sniffing["routeOnly"] = self.routeOnly
        return sniffing
    }
}

extension MGRouteModel {
    
    mutating func build() throws -> Any {
        self.rules = self.rules.filter(\.__enabled__)
        return try JSONSerialization.jsonObject(with: try JSONEncoder().encode(self))
    }
}
