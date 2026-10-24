import XCTest
@testable import DevWifiCore

final class PanelWidgetTests: XCTestCase {
    func testDefaultOrderMatchesV1() {
        XCTAssertEqual(PanelWidget.defaultOrder, [.signal, .traffic, .radar, .network])
        XCTAssertEqual(PanelWidget.defaultHidden, [.latency, .metric, .combined])
    }

    func testSanitizeRestoresMissingAndDropsUnknownDuplicates() {
        let result = PanelWidget.sanitized(order: [.radar, .radar, .signal], hidden: [.latency, .signal])
        XCTAssertEqual(result.order, [.radar, .signal, .traffic, .network, .latency, .metric, .combined])
        XCTAssertEqual(result.hidden, [.latency, .signal, .metric, .combined])
    }
}

final class WidgetSnapshotTests: XCTestCase {
    func testRoundTripJSON() throws {
        let original = WidgetSnapshot(
            ssid: "Office-5G",
            rssi: -40,
            channel: 36,
            quality: "Excellent",
            qualityPercent: 0.83,
            powerOn: true,
            connected: true,
            localIP: "10.0.0.8",
            gateway: "10.0.0.1",
            dns: "1.1.1.1 · Cloudflare",
            latencyMs: 24,
            downloadMbps: 12.4,
            uploadMbps: 1.1,
            downloadHistory: [1, 2, 3],
            latencyHistory: [20, 24],
            diagnosisTitle: "Saturated",
            diagnosisReason: "Cursor is filling the pipe.",
            diagnosisKind: .saturated,
            topApp: "Cursor",
            topAppHost: "api2.cursor.sh",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMakeCopiesPanelState() {
        var snapshot = NetworkSnapshot.empty
        snapshot.wifi = WifiInfo(ssid: "Home", rssi: -55, channel: 11, powerOn: true, connected: true)
        snapshot.localIP = "192.168.1.4"
        snapshot.dns = [DNSServer(address: "1.1.1.1"), DNSServer(address: "10.0.0.1")]
        snapshot.latencyMs = 18
        snapshot.downloadMbps = 4
        let diagnosis = AIDiagnosis(kind: .live, title: "Live", reason: "Cursor is on the link.")
        let flow = AIFlow(app: "Cursor", host: "api2.cursor.sh")

        let widget = WidgetSnapshot.make(
            snapshot: snapshot,
            downloadHistory: [1, 4],
            uploadHistory: [0.2],
            latencyHistory: [18],
            diagnosis: diagnosis,
            topFlow: flow
        )

        XCTAssertEqual(widget.ssid, "Home")
        XCTAssertEqual(widget.quality, "Good")
        XCTAssertEqual(widget.topApp, "Cursor")
        XCTAssertEqual(widget.diagnosisKind, .live)
        XCTAssertEqual(widget.dns, "1.1.1.1 · Cloudflare")
        XCTAssertEqual(widget.displayName, snapshot.wifi.displayName)
        XCTAssertEqual(widget.latencyHistory, [18])
    }

    func testMergeKeepsRadarFromStored() {
        let stored = WidgetSnapshot(
            diagnosisTitle: "Uplink lag",
            diagnosisKind: .uplinkLag,
            topApp: "Grok",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let live = WidgetSnapshot(rssi: -42, quality: "Excellent", qualityPercent: 0.8, powerOn: true, connected: true, localIP: "10.0.0.2", updatedAt: Date(timeIntervalSince1970: 20))
        let merged = stored.merging(live: live)
        XCTAssertEqual(merged.topApp, "Grok")
        XCTAssertEqual(merged.diagnosisKind, .uplinkLag)
        XCTAssertEqual(merged.rssi, -42)
        XCTAssertEqual(merged.localIP, "10.0.0.2")
    }
}
