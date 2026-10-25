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

    func testSignalQualityReadsBackFromRawValue() {
        for quality in SignalQuality.allCases {
            let snapshot = WidgetSnapshot(quality: quality.rawValue)
            XCTAssertEqual(snapshot.signalQuality, quality)
        }
    }

    func testSignalQualityIsNilWhenUnknownOrAbsent() {
        XCTAssertNil(WidgetSnapshot(quality: nil).signalQuality)
        XCTAssertNil(WidgetSnapshot(quality: "Superb").signalQuality)
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

    /// Golden fixture for the Codable shape `WidgetSnapshot` is persisted in.
    ///
    /// This is the exact JSON `WidgetSnapshotStore.write` on `main` produces for a
    /// snapshot with a non-default value in every stored property (generated once,
    /// by hand, from the real `JSONEncoder` configured with `.iso8601` dates and
    /// `.sortedKeys`, then pasted here — see `WidgetSnapshot.swift:157-159`).
    ///
    /// The app and the widget extension read and write this same file in the App
    /// Group (`group.com.tomymaritano.devwibar`) and can be on different versions
    /// of the binary at the same time during an update. That only stays safe if
    /// the stored shape doesn't change. `testRoundTripJSON` above encodes-then-
    /// decodes the *current* type, so it cannot catch a shape break: rename a
    /// stored property and it still round-trips with itself.
    ///
    /// If this test fails, a stored property was renamed, removed, or added
    /// without a default — i.e. an in-place App Group file written by an older
    /// build can no longer be read. The fix is a migration (e.g. custom
    /// `init(from:)` handling both old and new keys), NOT regenerating this
    /// fixture. Regenerating it to make the test pass again defeats the entire
    /// point of the test.
    func testDecodesFrozenGoldenFixture() throws {
        let json = """
        {"channel":149,"connected":true,"diagnosisKind":"uplinkLag","diagnosisReason":"Fixture reason text.","diagnosisTitle":"Fixture Diagnosis","dns":"8.8.8.8 \u{00B7} Google","downloadHistory":[1.1,2.2,3.3],"downloadMbps":45.6,"gateway":"10.20.30.1","latencyHistory":[100,110,120],"latencyMs":123.5,"localIP":"10.20.30.40","powerOn":true,"quality":"Weak","qualityPercent":0.42,"rssi":-55,"ssid":"Fixture-Net","topApp":"FixtureApp","topAppHost":"fixture.example.com","updatedAt":"2023-11-14T22:13:20Z","uploadHistory":[0.5,0.6],"uploadMbps":7.8}
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.ssid, "Fixture-Net")
        XCTAssertEqual(decoded.rssi, -55)
        XCTAssertEqual(decoded.channel, 149)
        XCTAssertEqual(decoded.quality, "Weak")
        XCTAssertEqual(decoded.qualityPercent, 0.42, accuracy: 0.0001)
        XCTAssertEqual(decoded.powerOn, true)
        XCTAssertEqual(decoded.connected, true)
        XCTAssertEqual(decoded.localIP, "10.20.30.40")
        XCTAssertEqual(decoded.gateway, "10.20.30.1")
        XCTAssertEqual(decoded.dns, "8.8.8.8 \u{00B7} Google")
        XCTAssertEqual(decoded.latencyMs, 123.5)
        XCTAssertEqual(decoded.downloadMbps, 45.6, accuracy: 0.0001)
        XCTAssertEqual(decoded.uploadMbps, 7.8, accuracy: 0.0001)
        XCTAssertEqual(decoded.downloadHistory, [1.1, 2.2, 3.3])
        XCTAssertEqual(decoded.uploadHistory, [0.5, 0.6])
        XCTAssertEqual(decoded.latencyHistory, [100.0, 110.0, 120.0])
        XCTAssertEqual(decoded.diagnosisTitle, "Fixture Diagnosis")
        XCTAssertEqual(decoded.diagnosisReason, "Fixture reason text.")
        XCTAssertEqual(decoded.diagnosisKind, .uplinkLag)
        XCTAssertEqual(decoded.topApp, "FixtureApp")
        XCTAssertEqual(decoded.topAppHost, "fixture.example.com")
        XCTAssertEqual(decoded.updatedAt, Date(timeIntervalSince1970: 1_700_000_000))

        // Computed, not stored — but its whole purpose is to be derived rather
        // than persisted, so pin that it still comes out right from the stored
        // `quality` string.
        XCTAssertEqual(decoded.signalQuality, .weak)
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
