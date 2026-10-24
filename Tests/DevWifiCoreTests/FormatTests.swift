import XCTest
@testable import DevWifiCore

final class FormatTests: XCTestCase {
    func testMbps() {
        XCTAssertEqual(Format.mbps(0), "0 Mbps")
        XCTAssertEqual(Format.mbps(1.234), "1.23 Mbps")
        XCTAssertEqual(Format.mbps(12.34), "12.3 Mbps")
        XCTAssertEqual(Format.mbps(420), "420 Mbps")
        XCTAssertEqual(Format.mbps(-1), "—")
    }

    func testLatency() {
        XCTAssertEqual(Format.latency(nil), "—")
        XCTAssertEqual(Format.latency(-1), "—")
        XCTAssertEqual(Format.latency(5.4), "5 ms")
        XCTAssertEqual(Format.latency(5.6), "6 ms")
    }

    func testBytes() {
        XCTAssertEqual(Format.bytes(512), "512 B")
        XCTAssertEqual(Format.bytes(1024), "1.00 KB")
        XCTAssertEqual(Format.bytes(1_048_576), "1.00 MB")
    }

    func testUpdated() {
        let now = Date()
        XCTAssertEqual(Format.updated(from: now, now: now), "Updated just now")
        XCTAssertEqual(Format.updated(from: now.addingTimeInterval(-12), now: now), "Updated 12s ago")
        XCTAssertEqual(Format.updated(from: now.addingTimeInterval(-180), now: now), "Updated 3m ago")
    }

    func testPercent() {
        XCTAssertEqual(Format.percent(0.72), "72%")
        XCTAssertEqual(Format.percent(1.4), "100%")
        XCTAssertEqual(Format.percent(-0.2), "0%")
    }

    func testDNSProviders() {
        XCTAssertEqual(DNSServer.provider(for: "1.1.1.1"), "Cloudflare")
        XCTAssertEqual(DNSServer.provider(for: "8.8.8.8"), "Google")
        XCTAssertEqual(DNSServer.provider(for: "9.9.9.9"), "Quad9")
        XCTAssertEqual(DNSServer.provider(for: "208.67.222.222"), "OpenDNS")
        XCTAssertEqual(DNSServer.provider(for: "192.168.1.1"), "Custom")
    }

    func testDNSLine() {
        XCTAssertEqual(DNSServer(address: "1.1.1.1").line, "1.1.1.1 · Cloudflare")
        XCTAssertEqual(DNSServer(address: "192.168.1.1").line, "192.168.1.1")
    }
}
