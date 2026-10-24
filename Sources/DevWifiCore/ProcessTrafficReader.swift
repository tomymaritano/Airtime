import Foundation

public struct ProcessTrafficSample: Equatable, Sendable {
    public var traffic: AITrafficSnapshot
    public var totals: [String: ProcessByteCounters]
    /// False when `lsof` did not exit. An empty finished listing stays true.
    public var probeFinished: Bool

    public init(
        traffic: AITrafficSnapshot,
        totals: [String: ProcessByteCounters],
        probeFinished: Bool
    ) {
        self.traffic = traffic
        self.totals = totals
        self.probeFinished = probeFinished
    }
}

public struct ProcessTrafficReader: Sendable {
    public var lsofOutput: @Sendable () -> CommandOutput
    public var nettopOutput: @Sendable () -> CommandOutput

    public init() {
        self.lsofOutput = {
            Shell.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:ESTABLISHED", "-F", "pcn"], timeout: 2.5)
        }
        self.nettopOutput = {
            Shell.run("/usr/bin/nettop", ["-P", "-L", "1", "-n", "-J", "bytes_in,bytes_out"], timeout: 2.5)
        }
    }

    public init(
        lsofOutput: @escaping @Sendable () -> CommandOutput,
        nettopOutput: @escaping @Sendable () -> CommandOutput
    ) {
        self.lsofOutput = lsofOutput
        self.nettopOutput = nettopOutput
    }

    public func sample(
        previousBytes: [String: ProcessByteCounters] = [:],
        elapsed: TimeInterval = 0,
        now: Date = Date()
    ) -> ProcessTrafficSample {
        let lsof = lsofOutput()
        guard lsof.finished else {
            return ProcessTrafficSample(
                traffic: AITrafficSnapshot(flows: [], updatedAt: now, hasBandwidth: false),
                totals: [:],
                probeFinished: false
            )
        }

        let nettop = nettopOutput()
        let processes = nettop.finished ? Self.parseNettop(nettop.text) : []
        let traffic = Self.assemble(
            connections: Self.parseLsof(lsof.text),
            processes: processes,
            previousBytes: nettop.finished ? previousBytes : [:],
            elapsed: nettop.finished ? elapsed : 0,
            now: now
        )
        let totals = nettop.finished ? Self.byteTotals(from: processes) : [:]
        return ProcessTrafficSample(traffic: traffic, totals: totals, probeFinished: true)
    }

    public func read(
        previousBytes: [String: ProcessByteCounters] = [:],
        elapsed: TimeInterval = 0,
        now: Date = Date()
    ) -> AITrafficSnapshot {
        sample(previousBytes: previousBytes, elapsed: elapsed, now: now).traffic
    }

    public static func parseLsof(_ output: String) -> [LsofConnection] {
        var connections: [LsofConnection] = []
        var process = ""
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let flag = line.first else { continue }
            let value = String(line.dropFirst())
            switch flag {
            case "p":
                process = ""
            case "c":
                process = value
            case "n":
                if let host = remoteHost(from: value), !process.isEmpty {
                    connections.append(LsofConnection(process: process, host: host))
                }
            default:
                break
            }
        }
        return connections
    }

    public static func parseNettop(_ output: String) -> [NettopProcess] {
        var rows: [NettopProcess] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(",bytes_") { continue }
            let parts = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 3 else { continue }
            let nameField = parts[0]
            guard let parsed = splitProcessPID(nameField),
                  let bytesIn = UInt64(parts[1]),
                  let bytesOut = UInt64(parts[2])
            else { continue }
            rows.append(NettopProcess(process: parsed.name, pid: parsed.pid, bytesIn: bytesIn, bytesOut: bytesOut))
        }
        return rows
    }

    public static func assemble(
        connections: [LsofConnection],
        processes: [NettopProcess],
        previousBytes: [String: ProcessByteCounters] = [:],
        elapsed: TimeInterval = 0,
        now: Date = Date()
    ) -> AITrafficSnapshot {
        var merged: [String: AIFlow] = [:]

        func upsert(app: String, host: String, provider: String, bytesIn: UInt64, bytesOut: UInt64) {
            var flow = merged[app] ?? AIFlow(app: app)
            if flow.host.isEmpty || AICatalog.isIPAddress(flow.host), !host.isEmpty {
                flow.host = host
            }
            if flow.provider.isEmpty {
                flow.provider = provider
            }
            flow.bytesIn += bytesIn
            flow.bytesOut += bytesOut
            merged[app] = flow
        }

        for connection in connections {
            guard let app = AICatalog.classify(process: connection.process, host: connection.host) else {
                continue
            }
            let provider = AICatalog.matchHost(connection.host) ?? app
            upsert(app: app, host: connection.host, provider: provider, bytesIn: 0, bytesOut: 0)
        }

        for process in processes {
            guard let app = AICatalog.matchProcess(process.process) else { continue }
            upsert(app: app, host: "", provider: app, bytesIn: process.bytesIn, bytesOut: process.bytesOut)
        }

        let hasBandwidth = elapsed > 0.4 && !previousBytes.isEmpty
        var flows = merged.values.map { flow -> AIFlow in
            var next = flow
            if hasBandwidth, let last = previousBytes[flow.app] {
                next.downloadMbps = megabitsPerSecond(
                    bytes: bytesDelta(previous: last.bytesIn, current: flow.bytesIn),
                    seconds: elapsed
                )
                next.uploadMbps = megabitsPerSecond(
                    bytes: bytesDelta(previous: last.bytesOut, current: flow.bytesOut),
                    seconds: elapsed
                )
            }
            return next
        }

        flows.sort { lhs, rhs in
            let left = (lhs.bytesIn + lhs.bytesOut)
            let right = (rhs.bytesIn + rhs.bytesOut)
            if left != right { return left > right }
            return lhs.app < rhs.app
        }

        return AITrafficSnapshot(flows: flows, updatedAt: now, hasBandwidth: hasBandwidth)
    }

    public static func byteTotals(from processes: [NettopProcess]) -> [String: ProcessByteCounters] {
        var totals: [String: ProcessByteCounters] = [:]
        for process in processes {
            guard let app = AICatalog.matchProcess(process.process) else { continue }
            let current = totals[app] ?? ProcessByteCounters(bytesIn: 0, bytesOut: 0)
            totals[app] = ProcessByteCounters(
                bytesIn: current.bytesIn + process.bytesIn,
                bytesOut: current.bytesOut + process.bytesOut
            )
        }
        return totals
    }

    public static func remoteHost(from name: String) -> String? {
        let remote: String
        if let arrow = name.range(of: "->") {
            remote = String(name[arrow.upperBound...])
        } else {
            remote = name
        }
        let trimmed = remote.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("[") {
            guard let close = trimmed.firstIndex(of: "]") else { return String(trimmed.drop(while: { $0 == "[" })) }
            return String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
        }

        if let colon = trimmed.lastIndex(of: ":"), trimmed[colon...].dropFirst().allSatisfy(\.isNumber) {
            return String(trimmed[..<colon])
        }
        return trimmed
    }

    public static func splitProcessPID(_ field: String) -> (name: String, pid: Int)? {
        guard let dot = field.lastIndex(of: "."),
              let pid = Int(field[field.index(after: dot)...])
        else { return nil }
        let name = String(field[..<dot])
        guard !name.isEmpty else { return nil }
        return (name, pid)
    }
}
