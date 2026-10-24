import Foundation
import os

private let widgetSnapshotLog = Logger(subsystem: "com.tomymaritano.devwibar", category: "widget-snapshot")

public struct WidgetSnapshot: Equatable, Sendable, Codable {
    public var ssid: String?
    public var rssi: Int?
    public var channel: Int?
    public var quality: String?
    public var qualityPercent: Double
    public var powerOn: Bool
    public var connected: Bool
    public var localIP: String
    public var gateway: String
    public var dns: String
    public var latencyMs: Double?
    public var downloadMbps: Double
    public var uploadMbps: Double
    public var downloadHistory: [Double]
    public var uploadHistory: [Double]
    public var latencyHistory: [Double]
    public var diagnosisTitle: String
    public var diagnosisReason: String
    public var diagnosisKind: AIDiagnosisKind
    public var topApp: String?
    public var topAppHost: String?
    public var updatedAt: Date

    public init(
        ssid: String? = nil,
        rssi: Int? = nil,
        channel: Int? = nil,
        quality: String? = nil,
        qualityPercent: Double = 0,
        powerOn: Bool = false,
        connected: Bool = false,
        localIP: String = "",
        gateway: String = "",
        dns: String = "",
        latencyMs: Double? = nil,
        downloadMbps: Double = 0,
        uploadMbps: Double = 0,
        downloadHistory: [Double] = [],
        uploadHistory: [Double] = [],
        latencyHistory: [Double] = [],
        diagnosisTitle: String = "Quiet",
        diagnosisReason: String = ProductName.openPrompt,
        diagnosisKind: AIDiagnosisKind = .idle,
        topApp: String? = nil,
        topAppHost: String? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.channel = channel
        self.quality = quality
        self.qualityPercent = qualityPercent
        self.powerOn = powerOn
        self.connected = connected
        self.localIP = localIP
        self.gateway = gateway
        self.dns = dns
        self.latencyMs = latencyMs
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.downloadHistory = downloadHistory
        self.uploadHistory = uploadHistory
        self.latencyHistory = latencyHistory
        self.diagnosisTitle = diagnosisTitle
        self.diagnosisReason = diagnosisReason
        self.diagnosisKind = diagnosisKind
        self.topApp = topApp
        self.topAppHost = topAppHost
        self.updatedAt = updatedAt
    }

    public static let empty = WidgetSnapshot()

    public var isFresh: Bool {
        Date().timeIntervalSince(updatedAt) < 120
    }

    public var displayName: String {
        WifiInfo(ssid: ssid, powerOn: powerOn, connected: connected).displayName
    }

    public static func make(
        snapshot: NetworkSnapshot,
        downloadHistory: [Double],
        uploadHistory: [Double],
        latencyHistory: [Double],
        diagnosis: AIDiagnosis,
        topFlow: AIFlow?
    ) -> WidgetSnapshot {
        return WidgetSnapshot(
            ssid: snapshot.wifi.ssid,
            rssi: snapshot.wifi.rssi,
            channel: snapshot.wifi.channel,
            quality: snapshot.wifi.quality?.rawValue,
            qualityPercent: snapshot.wifi.qualityPercent,
            powerOn: snapshot.wifi.powerOn,
            connected: snapshot.wifi.connected,
            localIP: snapshot.localIP,
            gateway: snapshot.gateway,
            dns: snapshot.dns.first?.line ?? "",
            latencyMs: snapshot.latencyMs,
            downloadMbps: snapshot.downloadMbps,
            uploadMbps: snapshot.uploadMbps,
            downloadHistory: downloadHistory,
            uploadHistory: uploadHistory,
            latencyHistory: latencyHistory,
            diagnosisTitle: diagnosis.title,
            diagnosisReason: diagnosis.reason,
            diagnosisKind: diagnosis.kind,
            topApp: topFlow?.app,
            topAppHost: topFlow?.host,
            updatedAt: snapshot.updatedAt
        )
    }

    /// Prefer live radio / IP, keep radar fields from the stored snapshot.
    public func merging(live: WidgetSnapshot) -> WidgetSnapshot {
        var merged = self
        merged.ssid = live.ssid ?? ssid
        merged.rssi = live.rssi ?? rssi
        merged.channel = live.channel ?? channel
        merged.quality = live.quality ?? quality
        merged.qualityPercent = live.rssi != nil ? live.qualityPercent : qualityPercent
        merged.powerOn = live.powerOn
        merged.connected = live.connected
        if !live.localIP.isEmpty { merged.localIP = live.localIP }
        if !live.gateway.isEmpty { merged.gateway = live.gateway }
        if !live.dns.isEmpty { merged.dns = live.dns }
        if live.latencyMs != nil { merged.latencyMs = live.latencyMs }
        merged.downloadMbps = live.downloadMbps
        merged.uploadMbps = live.uploadMbps
        if !live.downloadHistory.isEmpty { merged.downloadHistory = live.downloadHistory }
        if !live.uploadHistory.isEmpty { merged.uploadHistory = live.uploadHistory }
        if !live.latencyHistory.isEmpty { merged.latencyHistory = live.latencyHistory }
        merged.updatedAt = max(updatedAt, live.updatedAt)
        return merged
    }
}

public enum WidgetSnapshotStore {
    public static let appGroupID = "group.com.tomymaritano.devwibar"
    public static let fileName = "widget-snapshot.json"

    public static func write(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else {
            widgetSnapshotLog.error("Widget snapshot did not encode")
            return
        }
        let urls = writableURLs()
        if urls.isEmpty {
            widgetSnapshotLog.error("Widget snapshot has nowhere to write")
            return
        }
        for url in urls {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            } catch {
                widgetSnapshotLog.error("Widget snapshot was not written to \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    public static func read() -> WidgetSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for url in readableURLs() {
            guard let data = try? Data(contentsOf: url),
                  let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
            else { continue }
            return snapshot
        }
        return nil
    }

    public static func loadForWidget() -> WidgetSnapshot {
        let stored = read()
        let live = WidgetSnapshotSampler.live()
        if let stored, stored.isFresh {
            return stored
        }
        if let stored {
            return stored.merging(live: live)
        }
        return live
    }

    private static func writableURLs() -> [URL] {
        readableURLs()
    }

    private static func readableURLs() -> [URL] {
        var urls: [URL] = []
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            urls.append(group.appendingPathComponent(fileName))
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(support.appendingPathComponent(ProductName.display, isDirectory: true).appendingPathComponent(fileName))
        }
        return urls
    }
}

public enum WidgetSnapshotSampler {
    public static func live() -> WidgetSnapshot {
        let wifi = WifiReader().read()
        let net = NetworkReader().read(interfaceName: wifi.interfaceName)
        return WidgetSnapshot(
            ssid: wifi.ssid,
            rssi: wifi.rssi,
            channel: wifi.channel,
            quality: wifi.quality?.rawValue,
            qualityPercent: wifi.qualityPercent,
            powerOn: wifi.powerOn,
            connected: wifi.connected,
            localIP: net.localIP,
            gateway: net.gateway,
            dns: net.dns.first?.line ?? "",
            updatedAt: Date()
        )
    }
}
