import AppKit
import Combine
import DevWifiCore
import Foundation
import Network

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot = NetworkSnapshot.empty
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []
    @Published private(set) var latencyHistory: [Double] = []
    @Published private(set) var aiTraffic = AITrafficSnapshot.empty
    @Published private(set) var aiDiagnosis = AIDiagnosis.empty
    @Published var launchAtLoginEnabled = false
    @Published var copiedField: String?

    private let wifi = WifiReader()
    private let network = NetworkReader()
    private let latency = LatencyReader()
    private let counters = InterfaceCounters()
    private let trafficReader = ProcessTrafficReader()

    private var timer: Timer?
    private var pathMonitor: NWPathMonitor?
    private var lastBytes: (counters: ByteCounters, at: Date)?
    private var lastProcessBytes: [String: ProcessByteCounters] = [:]
    private var lastProcessBytesAt: Date?
    private var aiRefreshInFlight = false
    private var probeFinished = true
    private var pathSatisfied = false
    private var tickCount = 0
    private let historyLimit = 30

    func start() {
        guard timer == nil else { return }
        LocationGate.shared.requestIfNeeded()
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        startPathMonitor()
        refresh(includeLatency: true)
        refreshAITraffic()

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            let state = self
            Task { @MainActor in
                state?.handleTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.setEnabled(enabled)
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func copy(_ value: String, field: String) {
        guard !value.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        copiedField = field
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if copiedField == field {
                copiedField = nil
            }
        }
    }

    private func handleTick() {
        tickCount += 1
        refresh(includeLatency: tickCount.isMultiple(of: 4))
        if tickCount.isMultiple(of: 4) {
            refreshAITraffic()
        } else {
            applyBrief()
        }
    }

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            let state = self
            Task { @MainActor in
                state?.pathSatisfied = satisfied
                state?.refresh(includeLatency: false)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.tomymaritano.devwibar.path"))
        pathMonitor = monitor
    }

    private func refresh(includeLatency: Bool) {
        let wifiInfo = wifi.read()
        let net = network.read(interfaceName: wifiInfo.interfaceName)
        let bytes = counters.read(interfaceName: wifiInfo.interfaceName)
        let now = Date()

        var download = snapshot.downloadMbps
        var upload = snapshot.uploadMbps
        var totalRx = snapshot.totalRx
        var totalTx = snapshot.totalTx

        if let bytes {
            totalRx = bytes.rx
            totalTx = bytes.tx
            if let last = lastBytes {
                let elapsed = now.timeIntervalSince(last.at)
                if elapsed > 0.4 {
                    let sample = bandwidthSample(previous: last.counters, current: bytes, elapsed: elapsed)
                    download = sample.downloadMbps
                    upload = sample.uploadMbps
                    appendHistory(download: download, upload: upload)
                }
            }
            lastBytes = (bytes, now)
        }

        snapshot = NetworkSnapshot(
            wifi: wifiInfo,
            localIP: net.localIP,
            gateway: net.gateway,
            dns: net.dns,
            latencyMs: snapshot.latencyMs,
            downloadMbps: download,
            uploadMbps: upload,
            totalRx: totalRx,
            totalTx: totalTx,
            pathSatisfied: pathSatisfied,
            updatedAt: now
        )

        if includeLatency {
            Task {
                let ms = await latency.read()
                snapshot.latencyMs = ms
                snapshot.updatedAt = Date()
                if let ms {
                    appendLatency(ms)
                }
                applyBrief()
            }
        } else {
            applyBrief()
        }
    }

    private func refreshAITraffic() {
        guard !aiRefreshInFlight else { return }
        aiRefreshInFlight = true
        let reader = trafficReader
        let previous = lastProcessBytes
        let elapsed = lastProcessBytesAt.map { Date().timeIntervalSince($0) } ?? 0
        Task.detached {
            let sample = reader.sample(previousBytes: previous, elapsed: elapsed)
            await MainActor.run { [weak self] in
                let state = self
                state?.probeFinished = sample.probeFinished
                state?.aiTraffic = sample.traffic
                if !sample.totals.isEmpty {
                    state?.lastProcessBytes = sample.totals
                    state?.lastProcessBytesAt = Date()
                }
                state?.aiRefreshInFlight = false
                state?.applyBrief()
            }
        }
    }

    private func applyBrief() {
        let context = briefContext()
        aiDiagnosis = AIBrief.diagnose(context, previous: aiDiagnosis.kind)
        persistWidgetSnapshot()
    }

    private func persistWidgetSnapshot() {
        WidgetSnapshotStore.write(
            WidgetSnapshot.make(
                snapshot: snapshot,
                downloadHistory: downloadHistory,
                uploadHistory: uploadHistory,
                latencyHistory: latencyHistory,
                diagnosis: aiDiagnosis,
                topFlow: aiTraffic.topFlows.first
            )
        )
    }

    private func briefContext() -> AIBriefContext {
        AIBriefContext(
            quality: snapshot.wifi.quality,
            powerOn: snapshot.wifi.powerOn,
            connected: snapshot.wifi.connected,
            latencyMs: snapshot.latencyMs,
            downloadMbps: snapshot.downloadMbps,
            uploadMbps: snapshot.uploadMbps,
            downloadRising: AIBrief.isDownloadRising(current: snapshot.downloadMbps, history: downloadHistory),
            traffic: aiTraffic,
            probeFinished: probeFinished
        )
    }

    private func appendHistory(download: Double, upload: Double) {
        downloadHistory.append(download)
        uploadHistory.append(upload)
        if downloadHistory.count > historyLimit {
            downloadHistory.removeFirst(downloadHistory.count - historyLimit)
        }
        if uploadHistory.count > historyLimit {
            uploadHistory.removeFirst(uploadHistory.count - historyLimit)
        }
    }

    private func appendLatency(_ ms: Double) {
        latencyHistory.append(ms)
        if latencyHistory.count > historyLimit {
            latencyHistory.removeFirst(latencyHistory.count - historyLimit)
        }
    }
}
