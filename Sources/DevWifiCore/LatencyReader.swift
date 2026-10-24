import Foundation

public struct LatencyReader: Sendable {
    public init() {}

    public func read(host: String = "1.1.1.1") async -> Double? {
        await Task.detached(priority: .utility) {
            Self.ping(host: host)
        }.value
    }

    static func ping(host: String) -> Double? {
        #if os(macOS)
        let output = Shell.run("/sbin/ping", ["-c", "1", "-W", "2000", host])
        guard output.finished else { return nil }
        guard let match = output.text.range(of: #"time[=<]([0-9.]+)\s*ms"#, options: .regularExpression) else {
            return nil
        }
        let token = output.text[match]
        let number = token
            .replacingOccurrences(of: "time=", with: "")
            .replacingOccurrences(of: "time<", with: "")
            .replacingOccurrences(of: " ms", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(number)
        #else
        return nil
        #endif
    }
}
