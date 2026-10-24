import XCTest
@testable import DevWifiCore

final class AICatalogTests: XCTestCase {
    func testProcessMatching() {
        XCTAssertEqual(AICatalog.matchProcess("Cursor"), "Cursor")
        XCTAssertEqual(AICatalog.matchProcess("Cursor Helper (Plugin)"), "Cursor")
        XCTAssertEqual(AICatalog.matchProcess("cursorsandbox"), "Cursor")
        XCTAssertEqual(AICatalog.matchProcess("Claude Helper"), "Claude")
        XCTAssertEqual(AICatalog.matchProcess("Grok Bot"), "Grok")
        XCTAssertEqual(AICatalog.matchProcess("ChatGPT"), "ChatGPT")
        XCTAssertNil(AICatalog.matchProcess("Google Chrome Helper"))
        XCTAssertNil(AICatalog.matchProcess("node"))
        XCTAssertNil(AICatalog.matchProcess("Slack"))
    }

    func testHostMatching() {
        XCTAssertEqual(AICatalog.matchHost("api.openai.com"), "OpenAI")
        XCTAssertEqual(AICatalog.matchHost("api2.cursor.sh"), "Cursor")
        XCTAssertEqual(AICatalog.matchHost("generativelanguage.googleapis.com"), "Gemini")
        XCTAssertEqual(AICatalog.matchHost("api.anthropic.com"), "Anthropic")
        XCTAssertNil(AICatalog.matchHost("evilopenai.com"))
        XCTAssertNil(AICatalog.matchHost("googleapis.com"))
        XCTAssertNil(AICatalog.matchHost("example.com"))
    }

    func testClassifyPrefersProcessThenHost() {
        XCTAssertEqual(AICatalog.classify(process: "node", host: "api.openai.com"), "OpenAI")
        XCTAssertEqual(AICatalog.classify(process: "Cursor Helper", host: "1.1.1.1"), "Cursor")
        XCTAssertNil(AICatalog.classify(process: "node", host: "1.1.1.1"))
    }

    func testIPDetection() {
        XCTAssertTrue(AICatalog.isIPAddress("104.18.32.1"))
        XCTAssertTrue(AICatalog.isIPAddress("2001:db8::1"))
        XCTAssertFalse(AICatalog.isIPAddress("api.openai.com"))
    }
}

final class ProcessTrafficParserTests: XCTestCase {
    func testParseLsofMachineFormat() {
        let output = """
        p27517
        cClaude
        f12
        n10.8.0.7:53933->api.anthropic.com:443
        p39072
        cCursor Helper
        f20
        n10.8.0.7:49288->104.18.32.1:443
        p1365
        cGoogle Chrome Helper
        f23
        n10.8.0.7:59928->api.openai.com:443
        p1413
        cSlack Helper
        f8
        n10.8.0.7:49756->3.171.85.71:443
        """

        let connections = ProcessTrafficReader.parseLsof(output)
        XCTAssertEqual(connections.count, 4)
        XCTAssertEqual(connections[0], LsofConnection(process: "Claude", host: "api.anthropic.com"))
        XCTAssertEqual(connections[1].host, "104.18.32.1")
        XCTAssertEqual(connections[2].host, "api.openai.com")
    }

    func testRemoteHostIPv6AndArrow() {
        XCTAssertEqual(ProcessTrafficReader.remoteHost(from: "[::1]:58004->[::1]:3002"), "::1")
        XCTAssertEqual(ProcessTrafficReader.remoteHost(from: "10.0.0.1:80->api.openai.com:443"), "api.openai.com")
        XCTAssertEqual(ProcessTrafficReader.remoteHost(from: "example.com:443"), "example.com")
    }

    func testParseNettopCSV() {
        let output = """
        ,bytes_in,bytes_out,
        Cursor Helper.62690,7897,6973,
        Claude.27517,6261,8041,
        Google Chrome H.1365,90111993,9980097,
        Cursor Helper (.39072,3931948,630079,
        """

        let rows = ProcessTrafficReader.parseNettop(output)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].process, "Cursor Helper")
        XCTAssertEqual(rows[0].pid, 62690)
        XCTAssertEqual(rows[0].bytesIn, 7897)
        XCTAssertEqual(rows[3].process, "Cursor Helper (")
        XCTAssertEqual(rows[3].bytesIn, 3_931_948)
    }

    func testSplitProcessPID() {
        let parsed = ProcessTrafficReader.splitProcessPID("Grok Bot.5974")
        XCTAssertEqual(parsed?.name, "Grok Bot")
        XCTAssertEqual(parsed?.pid, 5974)
        XCTAssertNil(ProcessTrafficReader.splitProcessPID("not-a-row"))
    }

    func testAssembleMergesCursorHelpersAndIgnoresChromeWithoutHost() {
        let connections = [
            LsofConnection(process: "Claude", host: "api.anthropic.com"),
            LsofConnection(process: "Google Chrome Helper", host: "api.openai.com"),
            LsofConnection(process: "Slack Helper", host: "3.171.85.71"),
        ]
        let processes = [
            NettopProcess(process: "Cursor Helper", pid: 1, bytesIn: 1000, bytesOut: 100),
            NettopProcess(process: "Cursor Helper (", pid: 2, bytesIn: 4000, bytesOut: 200),
            NettopProcess(process: "Google Chrome H", pid: 3, bytesIn: 9_000_000, bytesOut: 1),
        ]

        let snapshot = ProcessTrafficReader.assemble(connections: connections, processes: processes)
        let apps = snapshot.flows.map(\.app)
        XCTAssertEqual(apps, ["Cursor", "Claude", "OpenAI"])
        XCTAssertEqual(snapshot.flows[0].bytesIn, 5000)
        XCTAssertEqual(snapshot.primaryApp, "Cursor")
        XCTAssertEqual(snapshot.flows.first(where: { $0.app == "OpenAI" })?.host, "api.openai.com")
    }

    func testAssembleRatesFromPreviousBytes() {
        let processes = [
            NettopProcess(process: "Claude", pid: 1, bytesIn: 1_250_000, bytesOut: 0),
        ]
        let previous = ["Claude": ProcessByteCounters(bytesIn: 0, bytesOut: 0)]
        let snapshot = ProcessTrafficReader.assemble(
            connections: [],
            processes: processes,
            previousBytes: previous,
            elapsed: 1
        )
        XCTAssertEqual(snapshot.flows[0].downloadMbps ?? 0, 10, accuracy: 0.001)
        XCTAssertTrue(snapshot.hasBandwidth)
    }

    func testReaderUsesInjectedOutput() {
        let reader = ProcessTrafficReader(
            lsofOutput: { .finished("p1\ncClaude\nn10.0.0.1:1->api.anthropic.com:443") },
            nettopOutput: { .finished(",bytes_in,bytes_out,\nClaude.1,100,20,") }
        )
        let sample = reader.sample()
        XCTAssertTrue(sample.probeFinished)
        XCTAssertEqual(sample.traffic.activeCount, 1)
        XCTAssertEqual(sample.traffic.primaryApp, "Claude")
    }

    func testFinishedEmptyLsofIsAnEmptyLink() {
        let reader = ProcessTrafficReader(
            lsofOutput: { .finished("") },
            nettopOutput: { .finished("") }
        )
        let sample = reader.sample()
        XCTAssertTrue(sample.probeFinished)
        XCTAssertTrue(sample.traffic.flows.isEmpty)
    }

    func testFailedLsofIsNotAnEmptyLink() {
        let reader = ProcessTrafficReader(
            lsofOutput: { .failed },
            nettopOutput: { .finished(",bytes_in,bytes_out,\nClaude.1,100,20,") }
        )
        let sample = reader.sample()
        XCTAssertFalse(sample.probeFinished)
        XCTAssertTrue(sample.traffic.flows.isEmpty)
        XCTAssertTrue(sample.totals.isEmpty)
    }
}

final class AIBriefTests: XCTestCase {
    func testNoAIApps() {
        let diagnosis = AIBrief.diagnose(AIBriefContext(traffic: .empty))
        XCTAssertEqual(diagnosis.kind, .idle)
        XCTAssertEqual(diagnosis.reason, "No AI apps on the link.")
    }

    func testUnfinishedProbeIsNotQuiet() {
        let diagnosis = AIBrief.diagnose(AIBriefContext(traffic: .empty, probeFinished: false))
        XCTAssertEqual(diagnosis.kind, .unreadable)
        XCTAssertEqual(diagnosis.title, "Couldn't read the link")
        XCTAssertFalse(diagnosis.reason.contains("No AI apps"))
    }

    func testOfflineAndDisconnected() {
        XCTAssertEqual(
            AIBrief.diagnose(AIBriefContext(powerOn: false, traffic: AITrafficSnapshot(flows: [AIFlow(app: "Cursor")]))).kind,
            .offline
        )
        XCTAssertEqual(
            AIBrief.diagnose(AIBriefContext(powerOn: false, probeFinished: false)).kind,
            .offline
        )
        XCTAssertEqual(
            AIBrief.diagnose(AIBriefContext(connected: false, traffic: AITrafficSnapshot(flows: [AIFlow(app: "Cursor")]))).kind,
            .disconnected
        )
    }

    func testStreamingWhenDownloadRises() {
        let traffic = AITrafficSnapshot(flows: [AIFlow(app: "Cursor")])
        let diagnosis = AIBrief.diagnose(AIBriefContext(downloadMbps: 3.2, downloadRising: true, traffic: traffic))
        XCTAssertEqual(diagnosis.kind, .streaming)
        XCTAssertEqual(diagnosis.title, "Streaming")
        XCTAssertTrue(diagnosis.reason.contains("Cursor"))
    }

    func testSaturatedLinkBlamesLLMNotSignal() {
        let traffic = AITrafficSnapshot(flows: [AIFlow(app: "Claude"), AIFlow(app: "Cursor")])
        let diagnosis = AIBrief.diagnose(AIBriefContext(
            quality: .excellent,
            latencyMs: 120,
            downloadMbps: 4,
            uploadMbps: 1,
            traffic: traffic
        ))
        XCTAssertEqual(diagnosis.kind, .saturated)
        XCTAssertEqual(diagnosis.title, "Saturated")
        XCTAssertTrue(diagnosis.reason.contains("120 ms"))
        XCTAssertTrue(diagnosis.reason.contains("80 ms"))
        XCTAssertTrue(diagnosis.evidence.contains(where: { $0.label == "Ping" && $0.tripped }))
        XCTAssertTrue(diagnosis.evidence.contains(where: { $0.label == "Traffic" && $0.tripped }))
    }

    func testGoodSignalAndLagBlamesUplink() {
        let traffic = AITrafficSnapshot(flows: [AIFlow(app: "Grok")])
        let diagnosis = AIBrief.diagnose(AIBriefContext(
            quality: .good,
            latencyMs: 95,
            downloadMbps: 0.4,
            traffic: traffic
        ))
        XCTAssertEqual(diagnosis.kind, .uplinkLag)
        XCTAssertEqual(diagnosis.title, "Uplink lag")
        XCTAssertTrue(diagnosis.reason.contains("95 ms"))
    }

    func testSaturatedHoldsUntilClear() {
        let traffic = AITrafficSnapshot(flows: [AIFlow(app: "Cursor")])
        let cooling = AIBriefContext(quality: .excellent, latencyMs: 70, downloadMbps: 2.0, traffic: traffic)
        let held = AIBrief.diagnose(cooling, previous: .saturated)
        XCTAssertEqual(held.kind, .saturated)
        let cleared = AIBrief.diagnose(
            AIBriefContext(quality: .excellent, latencyMs: 40, downloadMbps: 0.4, traffic: traffic),
            previous: .saturated
        )
        XCTAssertEqual(cleared.kind, .live)
    }

    func testConnectedAndMultipleApps() {
        XCTAssertEqual(
            AIBrief.diagnose(AIBriefContext(traffic: AITrafficSnapshot(flows: [AIFlow(app: "Claude")]))).kind,
            .live
        )
        XCTAssertEqual(
            AIBrief.diagnose(AIBriefContext(traffic: AITrafficSnapshot(flows: [AIFlow(app: "Claude"), AIFlow(app: "Grok")]))).title,
            "On the link"
        )
    }

    func testDownloadRisingHeuristic() {
        XCTAssertTrue(AIBrief.isDownloadRising(current: 6, history: [0.2, 0.3]))
        XCTAssertTrue(AIBrief.isDownloadRising(current: 3, history: [0.4, 0.5, 0.4]))
        XCTAssertFalse(AIBrief.isDownloadRising(current: 0.8, history: [0.4, 0.5]))
        XCTAssertFalse(AIBrief.isDownloadRising(current: 2.1, history: [2.0, 2.2, 2.1]))
    }
}
