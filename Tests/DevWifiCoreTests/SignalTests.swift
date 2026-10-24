import XCTest
@testable import DevWifiCore

final class SignalTests: XCTestCase {
    func testQualityThresholds() {
        XCTAssertEqual(SignalQuality.from(dbm: -30), .excellent)
        XCTAssertEqual(SignalQuality.from(dbm: -50), .excellent)
        XCTAssertEqual(SignalQuality.from(dbm: -51), .good)
        XCTAssertEqual(SignalQuality.from(dbm: -60), .good)
        XCTAssertEqual(SignalQuality.from(dbm: -61), .fair)
        XCTAssertEqual(SignalQuality.from(dbm: -70), .fair)
        XCTAssertEqual(SignalQuality.from(dbm: -71), .weak)
        XCTAssertEqual(SignalQuality.from(dbm: -80), .weak)
        XCTAssertEqual(SignalQuality.from(dbm: -81), .veryWeak)
        XCTAssertEqual(SignalQuality.from(dbm: -90), .veryWeak)
    }

    func testRssiPercentBounds() {
        XCTAssertEqual(rssiToPercent(-30), 1, accuracy: 0.001)
        XCTAssertEqual(rssiToPercent(-90), 0, accuracy: 0.001)
        XCTAssertEqual(rssiToPercent(-60), 0.5, accuracy: 0.001)
        XCTAssertEqual(rssiToPercent(-10), 1, accuracy: 0.001)
        XCTAssertEqual(rssiToPercent(-120), 0, accuracy: 0.001)
    }
}
