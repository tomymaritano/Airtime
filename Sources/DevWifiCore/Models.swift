import Foundation

public struct DNSServer: Equatable, Sendable, Identifiable {
    public var address: String
    public var provider: String

    public var id: String { address }

    public init(address: String, provider: String? = nil) {
        self.address = address
        self.provider = provider ?? DNSServer.provider(for: address)
    }

    public static func provider(for address: String) -> String {
        switch address {
        case "1.1.1.1", "1.0.0.1", "1.1.1.2", "1.0.0.2",
             "2606:4700:4700::1111", "2606:4700:4700::1001":
            return "Cloudflare"
        case "8.8.8.8", "8.8.4.4",
             "2001:4860:4860::8888", "2001:4860:4860::8844":
            return "Google"
        case "9.9.9.9", "149.112.112.112",
             "2620:fe::fe", "2620:fe::9":
            return "Quad9"
        case "208.67.222.222", "208.67.220.220":
            return "OpenDNS"
        default:
            return "Custom"
        }
    }

    /// Panel and widget share this row. A custom resolver stays the address alone.
    public var line: String {
        provider == "Custom" ? address : "\(address) · \(provider)"
    }
}

public struct WifiInfo: Equatable, Sendable {
    public var ssid: String?
    public var rssi: Int?
    public var channel: Int?
    public var bssid: String?
    public var transmitRateMbps: Double?
    public var interfaceName: String
    public var powerOn: Bool
    public var connected: Bool

    public init(
        ssid: String? = nil,
        rssi: Int? = nil,
        channel: Int? = nil,
        bssid: String? = nil,
        transmitRateMbps: Double? = nil,
        interfaceName: String = "en0",
        powerOn: Bool = false,
        connected: Bool = false
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.channel = channel
        self.bssid = bssid
        self.transmitRateMbps = transmitRateMbps
        self.interfaceName = interfaceName
        self.powerOn = powerOn
        self.connected = connected
    }

    public var quality: SignalQuality? {
        rssi.map(SignalQuality.from(dbm:))
    }

    public var qualityPercent: Double {
        rssi.map(rssiToPercent) ?? 0
    }

    public var displayName: String {
        if !powerOn { return "Wi-Fi Off" }
        if !connected { return "Disconnected" }
        return ssid ?? "Wi-Fi"
    }

    public static let unavailable = WifiInfo()
}

public struct NetworkSnapshot: Equatable, Sendable {
    public var wifi: WifiInfo
    public var localIP: String
    public var gateway: String
    public var dns: [DNSServer]
    public var latencyMs: Double?
    public var downloadMbps: Double
    public var uploadMbps: Double
    public var totalRx: UInt64
    public var totalTx: UInt64
    public var pathSatisfied: Bool
    public var updatedAt: Date

    public init(
        wifi: WifiInfo = .unavailable,
        localIP: String = "",
        gateway: String = "",
        dns: [DNSServer] = [],
        latencyMs: Double? = nil,
        downloadMbps: Double = 0,
        uploadMbps: Double = 0,
        totalRx: UInt64 = 0,
        totalTx: UInt64 = 0,
        pathSatisfied: Bool = false,
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.wifi = wifi
        self.localIP = localIP
        self.gateway = gateway
        self.dns = dns
        self.latencyMs = latencyMs
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.totalRx = totalRx
        self.totalTx = totalTx
        self.pathSatisfied = pathSatisfied
        self.updatedAt = updatedAt
    }

    public static let empty = NetworkSnapshot()

    public var isOnline: Bool {
        pathSatisfied && wifi.connected && wifi.powerOn
    }
}
