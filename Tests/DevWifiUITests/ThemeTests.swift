import DevWifiCore
import SwiftUI
import XCTest
@testable import DevWifiUI

final class ThemeTests: XCTestCase {
    // MARK: - Latency

    /// `color(forLatency:)` compares with `>=` against `AIBrief.latencyHighMs`,
    /// which is off-by-one-able. The exact boundary uses the real constant so
    /// this test doesn't silently drift if the threshold changes; the
    /// just-below/just-above cases are written as an explicit +/- 0.1 delta off
    /// that constant so the off-by-one is still visible at a glance.
    func testLatencyBoundary() {
        XCTAssertEqual(Theme.color(forLatency: AIBrief.latencyHighMs - 0.1), Theme.ok)
        XCTAssertEqual(Theme.color(forLatency: AIBrief.latencyHighMs), Theme.load)
        XCTAssertEqual(Theme.color(forLatency: AIBrief.latencyHighMs + 0.1), Theme.load)
        XCTAssertEqual(Theme.color(forLatency: nil), Theme.secondary)
    }

    // MARK: - Upload saturation

    /// Same `>=` shape as latency, against `AIBrief.saturateMbps`.
    func testUploadSaturationBoundary() {
        XCTAssertEqual(Theme.color(forUpload: AIBrief.saturateMbps - 0.1), .primary)
        XCTAssertEqual(Theme.color(forUpload: AIBrief.saturateMbps), Theme.load)
        XCTAssertEqual(Theme.color(forUpload: AIBrief.saturateMbps + 0.1), Theme.load)
    }

    // MARK: - Signal quality

    /// Exhaustive over `SignalQuality.allCases` so a new case can't slip
    /// through untested. `.fair` is covered here too (as `.primary`), and
    /// again on its own below because it's the whole point of the file.
    func testSignalQualityMapsEveryCase() {
        for quality in SignalQuality.allCases {
            let expected: Color
            switch quality {
            case .excellent, .good: expected = Theme.ok
            case .fair: expected = .primary
            case .weak: expected = Theme.load
            case .veryWeak: expected = Theme.bad
            }
            XCTAssertEqual(Theme.color(for: quality), expected, "\(quality) mapped unexpectedly")
        }
    }

    func testSignalQualityNilIsSecondary() {
        XCTAssertEqual(Theme.color(for: nil), Theme.secondary)
    }

    /// `.fair` is deliberately `.primary`, not green. In this system colour
    /// means "look at this": fair is neither good nor bad, so it gets no
    /// colour at all. That decision otherwise lives only in a source comment
    /// that anyone could "fix" by making fair green — this assertion is the
    /// point of the whole file.
    func testFairIsDeliberatelyUncolored() {
        XCTAssertEqual(Theme.color(for: .fair), .primary)
    }

    // MARK: - Diagnosis kind

    /// `AIDiagnosisKind` isn't `CaseIterable`, so exhaustiveness is enforced
    /// by the compiler instead: this switch has no `default`, so adding a new
    /// case to the enum fails this file to compile until it's handled here.
    func testDiagnosisKindMapsEveryCase() {
        for kind: AIDiagnosisKind in [.saturated, .uplinkLag, .streaming, .live, .idle, .unreadable, .offline, .disconnected] {
            let expected: Color
            switch kind {
            case .saturated, .uplinkLag: expected = Theme.load
            case .streaming, .live: expected = Theme.down
            case .idle: expected = Theme.ok
            case .unreadable, .offline, .disconnected: expected = Theme.secondary
            }
            XCTAssertEqual(Theme.color(for: kind), expected, "\(kind) mapped unexpectedly")
        }
    }
}
