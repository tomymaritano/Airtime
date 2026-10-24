import Foundation

#if os(macOS)
import SystemConfiguration
#endif

public struct NetworkReader: Sendable {
    public init() {}

    public func read(interfaceName: String) -> (localIP: String, gateway: String, dns: [DNSServer]) {
        (
            localIP: localIP(interfaceName: interfaceName),
            gateway: gateway(),
            dns: dnsServers()
        )
    }

    public func localIP(interfaceName: String) -> String {
        #if os(macOS)
        let fromConfig = Shell.run("/usr/sbin/ipconfig", ["getifaddr", interfaceName]).text
        if !fromConfig.isEmpty, fromConfig.contains(".") {
            return fromConfig
        }
        #endif
        return ""
    }

    public func gateway() -> String {
        #if os(macOS)
        let output = Shell.run("/sbin/route", ["-n", "get", "default"]).text
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("gateway:") {
                return trimmed.dropFirst("gateway:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        #endif
        return ""
    }

    public func dnsServers() -> [DNSServer] {
        #if os(macOS)
        guard let store = SCDynamicStoreCreate(nil, "DevWifiBar" as CFString, nil, nil) else {
            return []
        }
        let key = "State:/Network/Global/DNS" as CFString
        guard let raw = SCDynamicStoreCopyValue(store, key) as? [String: Any],
              let addresses = raw["ServerAddresses"] as? [String]
        else {
            return []
        }
        return addresses.map { DNSServer(address: $0) }
        #else
        return []
        #endif
    }
}
