# Airtime Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the panel, the seven desktop widgets and the brand mark on one design system, held in a shared target so they cannot desynchronise again.

**Architecture:** A new `DevWifiUI` SwiftPM target sits between `DevWifiCore` (logic, SwiftUI-free) and the two consumers — the `DevWifiBar` app and the `DevWifiBarWidgets` extension. It holds the colour tokens, the card container, the charts and the small atoms. The panel adopts a redesign that replaces the teal brand colour with macOS system colours used semantically; the widgets then mirror their matching panel card.

**Tech Stack:** Swift 5.10, SwiftUI, WidgetKit, AppKit, SwiftPM + XcodeGen, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-24-airtime-redesign-design.md`

## Global Constraints

- Minimum platform: macOS 14. Do not raise it.
- `project.yml` must keep `projectFormat: xcode15_3`. CI runs Xcode 15.4 on `macos-14`, which cannot open objectVersion 77.
- Every new SwiftPM target sets `swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]`, matching the existing targets.
- `DevWifiCore` stays SwiftUI-free. No `import SwiftUI` in that target, ever.
- `DevWifiUI` must be safe for application extensions: no `NSWorkspace`, no `NSApplication`, no `NSStatusBar`. The widget target builds with `APPLICATION_EXTENSION_API_ONLY: YES` and will fail if this is violated.
- `WidgetSnapshot`'s stored properties and their types are frozen. It is `Codable` and persisted in the App Group `group.com.tomymaritano.devwibar`, shared by app and extension; changing a stored type breaks reads while two versions coexist. Add computed properties only.
- Airtime is dark everywhere. Widgets do not adapt to light mode.
- Colour tokens are literal hex via `Color(red:green:blue:)`. Do not substitute `Color(nsColor:)` system colours — they resolve per appearance and would break the fixed-dark decision.
- Teal is gone. No `Color(red: 0.18, green: 0.83, blue: 0.75)` may remain anywhere when the plan completes.
- Commit after every task. Build commands: `swift build` (package), `make test` (unit tests), `make widgets` (xcodegen + xcodebuild for the extension).

---

### Task 1: Core accessors for signal quality

Two pure-data mappings the UI layers need. They live in `DevWifiCore` rather than the SwiftUI layer because neither needs SwiftUI — one returns `Int`, the other re-reads an enum from its `rawValue` — and keeping them here means the existing test target covers them without a new one.

**Files:**
- Modify: `Sources/DevWifiCore/Signal.swift`
- Modify: `Sources/DevWifiCore/WidgetSnapshot.swift`
- Test: `Tests/DevWifiCoreTests/SignalTests.swift`
- Test: `Tests/DevWifiCoreTests/WidgetTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `SignalQuality.segments -> Int` (5 for `.excellent` down to 1 for `.veryWeak`). `WidgetSnapshot.signalQuality -> SignalQuality?`.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/DevWifiCoreTests/SignalTests.swift`, inside `final class SignalTests`:

```swift
    func testSegmentsPerQuality() {
        XCTAssertEqual(SignalQuality.excellent.segments, 5)
        XCTAssertEqual(SignalQuality.good.segments, 4)
        XCTAssertEqual(SignalQuality.fair.segments, 3)
        XCTAssertEqual(SignalQuality.weak.segments, 2)
        XCTAssertEqual(SignalQuality.veryWeak.segments, 1)
    }

    func testSegmentsCoverEveryCase() {
        for quality in SignalQuality.allCases {
            XCTAssertTrue((1...5).contains(quality.segments), "\(quality) is outside 1...5")
        }
    }
```

Append to `Tests/DevWifiCoreTests/WidgetTests.swift`, inside `final class PanelWidgetTests`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `make test`
Expected: FAIL — `value of type 'SignalQuality' has no member 'segments'` and `value of type 'WidgetSnapshot' has no member 'signalQuality'`.

- [ ] **Step 3: Add `segments`**

Append to `Sources/DevWifiCore/Signal.swift`:

```swift
extension SignalQuality {
    /// Lit segments in the five-step meter.
    public var segments: Int {
        switch self {
        case .excellent: return 5
        case .good: return 4
        case .fair: return 3
        case .weak: return 2
        case .veryWeak: return 1
        }
    }
}
```

- [ ] **Step 4: Add `signalQuality`**

In `Sources/DevWifiCore/WidgetSnapshot.swift`, inside `public struct WidgetSnapshot`, directly below `public var displayName: String { ... }`:

```swift
    /// `quality` is stored as a String so the Codable shape stays stable across
    /// versions that share the App Group. Views need the enum.
    public var signalQuality: SignalQuality? {
        quality.flatMap(SignalQuality.init(rawValue:))
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `make test`
Expected: PASS, all suites.

- [ ] **Step 6: Commit**

```bash
git add Sources/DevWifiCore/Signal.swift Sources/DevWifiCore/WidgetSnapshot.swift Tests/DevWifiCoreTests/SignalTests.swift Tests/DevWifiCoreTests/WidgetTests.swift
git commit -m "feat: read signal quality as an enum from the widget snapshot"
```

---

### Task 2: The DevWifiUI target and its tokens

Creates the shared layer and fills it with the colour and metric tokens. Nothing consumes it yet; the deliverable is that the package builds with the new target in place.

**Files:**
- Modify: `Package.swift`
- Create: `Sources/DevWifiUI/Tokens.swift`

**Interfaces:**
- Consumes: `SignalQuality`, `AIDiagnosisKind`, `AIBrief.latencyHighMs` from `DevWifiCore`.
- Produces: `public enum Theme` with the token constants and three `color(for:)` overloads, importable as `import DevWifiUI`.

- [ ] **Step 1: Add the target and product to `Package.swift`**

In the `products:` array, after the `DevWifiCore` library:

```swift
        .library(name: "DevWifiUI", targets: ["DevWifiUI"]),
```

In the `targets:` array, between the `DevWifiCore` target and the `DevWifiBar` executable target:

```swift
        .target(
            name: "DevWifiUI",
            dependencies: ["DevWifiCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
```

In the `DevWifiBar` executable target, change the dependencies line to:

```swift
            dependencies: ["DevWifiCore", "DevWifiUI"],
```

- [ ] **Step 2: Create `Sources/DevWifiUI/Tokens.swift`**

```swift
import DevWifiCore
import SwiftUI

/// Panel and widget tokens. Dark macOS system colours, so values read the same
/// as the rest of the menu bar. Airtime is dark everywhere: these are literal
/// hex on purpose, not `Color(nsColor:)` system colours that resolve per
/// appearance.
public enum Theme {
    // Surfaces
    public static let background = Color(red: 0.110, green: 0.110, blue: 0.118) // #1C1C1E
    public static let card = Color(red: 0.165, green: 0.165, blue: 0.176)       // #2A2A2D
    public static let divider = Color.white.opacity(0.08)
    public static let hairline = Color.white.opacity(0.12)

    // Text
    public static let body = Color(red: 0.820, green: 0.820, blue: 0.839)       // #D1D1D6
    public static let secondary = Color(red: 0.596, green: 0.596, blue: 0.624)  // #98989F

    // Semantics. Colour means "look at this"; its absence is also a signal.
    /// Ping or traffic over the line, and the Saturated / Uplink lag verdicts.
    public static let load = Color(red: 1.0, green: 0.624, blue: 0.039)         // #FF9F0A
    /// Healthy signal, low ping, Quiet.
    public static let ok = Color(red: 0.188, green: 0.820, blue: 0.345)         // #30D158
    /// Download series and links.
    public static let down = Color(red: 0.416, green: 0.706, blue: 1.0)         // #6AB4FF
    /// Weak and very weak signal.
    public static let bad = Color(red: 1.0, green: 0.412, blue: 0.380)          // #FF6961
    /// Controls that are on.
    public static let control = Color(red: 0.039, green: 0.392, blue: 0.847)    // #0A64D8

    // Metrics
    public static let panelWidth: CGFloat = 360
    public static let panelPadding: CGFloat = 12
    public static let cardSpacing: CGFloat = 8
    public static let cardPadding: CGFloat = 12
    public static let cardRadius: CGFloat = 10
    /// Widgets own their container, which is roomier than a panel card.
    public static let widgetPadding: CGFloat = 14

    /// Fair returns `.primary`: it is neither good nor bad, and the absence of
    /// colour is the signal.
    public static func color(for quality: SignalQuality?) -> Color {
        switch quality {
        case .excellent, .good: return ok
        case .fair: return .primary
        case .weak: return load
        case .veryWeak: return bad
        case nil: return secondary
        }
    }

    public static func color(forLatency ms: Double?) -> Color {
        guard let ms else { return secondary }
        return ms >= AIBrief.latencyHighMs ? load : ok
    }

    public static func color(for kind: AIDiagnosisKind) -> Color {
        switch kind {
        case .saturated, .uplinkLag: return load
        case .streaming, .live: return down
        case .idle: return ok
        case .unreadable, .offline, .disconnected: return secondary
        }
    }
}
```

- [ ] **Step 3: Verify the package builds**

Run: `swift build`
Expected: succeeds. `DevWifiUI` compiles; the app target still uses its own local `Theme` and is untouched.

- [ ] **Step 4: Verify the tests still pass**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/DevWifiUI/Tokens.swift
git commit -m "feat: add a DevWifiUI target holding the shared tokens"
```

---

### Task 3: The shared primitives

Fills `DevWifiUI` with the composition pieces both consumers use: the card container, the charts and the small atoms. `BrandMarkView` moves here from the app target so the widget copy can be deleted in Task 9.

**Files:**
- Create: `Sources/DevWifiUI/Card.swift`
- Create: `Sources/DevWifiUI/Charts.swift`
- Create: `Sources/DevWifiUI/Atoms.swift`
- Create: `Sources/DevWifiUI/BrandMarkView.swift`

Nothing is deleted from the app target in this task. The app keeps its own
`BrandMarkView` and `Views/SparklineView.swift` until Task 5, so every task in
between still builds. A type defined in the app module shadows a same-named
`public` type from an imported module, so the duplication is inert rather than
ambiguous.

**Interfaces:**
- Consumes: `Theme` from Task 2.
- Produces: `CardTitle(text:)`, `View.card(padding:)`, `SparklineView(values:color:peak:lineWidth:)`, `SignalMeter(filled:color:)`, `ShareBar(share:color:)`, `StatusDot(color:)`, `ChipTint`, `EvidenceChip(label:value:tint:)`, `RowButtonStyle()`, `BrandMarkView(offline:color:)`.

- [ ] **Step 1: Create `Sources/DevWifiUI/Card.swift`**

```swift
import SwiftUI

/// Small uppercase card title, e.g. "ON THE LINK".
public struct CardTitle: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Theme.secondary)
    }
}

public struct CardBackground: ViewModifier {
    private let padding: CGFloat

    public init(padding: CGFloat = Theme.cardPadding) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

extension View {
    /// The one container. Cards separate themselves; the panel draws no dividers between them.
    public func card(padding: CGFloat = Theme.cardPadding) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
```

- [ ] **Step 2: Create `Sources/DevWifiUI/Charts.swift`**

```swift
import SwiftUI

/// Line sparkline. Pass `peak` to put several series on one scale.
public struct SparklineView: View {
    private let values: [Double]
    private let color: Color
    private let peak: Double?
    private let lineWidth: CGFloat

    public init(values: [Double], color: Color = Theme.down, peak: Double? = nil, lineWidth: CGFloat = 2) {
        self.values = values
        self.color = color
        self.peak = peak
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            if values.count < 2 {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: geo.size.width, height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            } else {
                SparklinePath(values: values, peak: max(peak ?? values.max() ?? 0, 0.001))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SparklinePath: Shape {
    let values: [Double]
    let peak: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.insetBy(dx: 1, dy: 2)
        let step = inset.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let ratio = CGFloat(min(max(value / peak, 0), 1))
            let point = CGPoint(x: inset.minX + CGFloat(index) * step, y: inset.maxY - ratio * inset.height)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// Five segments, one per signal quality step.
public struct SignalMeter: View {
    private let filled: Int
    private let color: Color

    public init(filled: Int, color: Color) {
        self.filled = filled
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? color : Color.white.opacity(0.10))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Proportional bar. `share` is already clamped by the caller.
public struct ShareBar: View {
    private let share: Double
    private let color: Color

    public init(share: Double, color: Color) {
        self.share = share
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(color).frame(width: geo.size.width * share)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 3: Create `Sources/DevWifiUI/Atoms.swift`**

```swift
import SwiftUI

/// 8pt dot that carries a semantic colour beside a label.
public struct StatusDot: View {
    private let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

/// A chip is either neutral or carries a semantic colour. Modelled explicitly
/// rather than by comparing a `Color` to `.primary`, which hides the intent.
public enum ChipTint {
    case neutral
    case semantic(Color)

    var foreground: Color {
        switch self {
        case .neutral: return .primary
        case .semantic(let color): return color
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Color.white.opacity(0.06)
        case .semantic(let color): return color.opacity(0.15)
        }
    }
}

/// Label over a large monospaced value, e.g. "Ping" / "120 ms".
public struct EvidenceChip: View {
    private let label: String
    private let value: String
    private let tint: ChipTint

    public init(label: String, value: String, tint: ChipTint) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.78))
            Text(value)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Row that lights on hover and deepens on press. Panel only — widgets are not interactive.
public struct RowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HoverRow(label: configuration.label, pressed: configuration.isPressed)
    }
}

private struct HoverRow<Label: View>: View {
    let label: Label
    let pressed: Bool
    @State private var hovering = false

    var body: some View {
        label
            .background(
                Color.white.opacity(pressed ? 0.10 : (hovering ? 0.05 : 0)),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .onHover { hovering = $0 }
    }
}
```

- [ ] **Step 4: Create `Sources/DevWifiUI/BrandMarkView.swift`**

This is the body of `BrandMarkView` moved verbatim from `Sources/DevWifiBar/BrandMark.swift`, made public. It uses only SwiftUI `Canvas`, so it is extension-safe.

```swift
import SwiftUI

/// Wi-Fi fan on a bar — the Airtime mark.
public struct BrandMarkView: View {
    private let offline: Bool
    private let color: Color

    public init(offline: Bool = false, color: Color = .primary) {
        self.offline = offline
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.08, dy: size.height * 0.10)
            let w = rect.width
            let h = rect.height
            let origin = CGPoint(x: rect.midX, y: rect.maxY - h * 0.22)
            let ink = color.opacity(offline ? 0.35 : 1)

            let bar = CGRect(x: rect.minX + w * 0.12, y: rect.maxY - h * 0.16, width: w * 0.76, height: h * 0.13)
            context.fill(Path(roundedRect: bar, cornerRadius: bar.height / 2), with: .color(ink))

            let stroke = max(1.7, w * 0.13)
            for radius in [w * 0.22, w * 0.40, w * 0.58] {
                var arc = Path()
                arc.addArc(center: origin, radius: radius, startAngle: .degrees(210), endAngle: .degrees(330), clockwise: false)
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 5: Verify the package builds**

Run: `swift build`
Expected: succeeds. `DevWifiUI` now compiles with all five files; the app target is untouched and still uses its own copies.

- [ ] **Step 6: Commit**

```bash
git add Sources/DevWifiUI
git commit -m "feat: move the card, charts, atoms and mark into DevWifiUI"
```

---

### Task 4: Wire the widget extension to DevWifiUI

The extension gets the dependency before any widget uses it, so a build failure here is isolated from the view rewrites. `DevWifiCore` is already wired the same way, so the mechanism has a working precedent in this repo.

**Files:**
- Modify: `project.yml`

**Interfaces:**
- Consumes: the `DevWifiUI` library product from Task 2.
- Produces: `import DevWifiUI` available inside `Sources/DevWifiBarWidgets`.

- [ ] **Step 1: Add the dependency**

In `project.yml`, under `targets.DevWifiBarWidgets.dependencies`, extend the list to:

```yaml
    dependencies:
      - package: DevWifiPackage
        product: DevWifiCore
      - package: DevWifiPackage
        product: DevWifiUI
```

Leave `projectFormat: xcode15_3` and every setting under `settings.base` untouched.

- [ ] **Step 2: Prove the import resolves**

Temporarily add `import DevWifiUI` as the first line of `Sources/DevWifiBarWidgets/DevWifiBarWidgets.swift`.

- [ ] **Step 3: Build the extension**

Run: `make widgets`
Expected: `xcodegen generate` rewrites `DevWifiBar.xcodeproj`, then `xcodebuild` succeeds. A warning about linking a library not built with `APPLICATION_EXTENSION_API_ONLY` is expected and harmless — SwiftPM targets link statically here, exactly as `DevWifiCore` already does. An *error* naming an unavailable API means something app-only leaked into `DevWifiUI`; fix it there rather than relaxing the setting.

- [ ] **Step 4: Remove the temporary import**

Delete the `import DevWifiUI` line added in Step 2. `DevWifiBarWidgets.swift` only registers widgets and does not need it; Task 10 adds the import to the files that do.

- [ ] **Step 5: Commit**

```bash
git add project.yml
git commit -m "build: let the widget extension link DevWifiUI"
```

---

### Task 5: Panel shell

Deletes the app's local `Theme`, switches the panel to a stack of cards on a 360pt dark surface, and rebuilds the header and footer. After this task the app builds and runs, but the individual section cards still carry their old teal bodies — they are rewritten in Tasks 6 and 7.

**Files:**
- Delete: `Sources/DevWifiBar/Theme.swift`
- Delete: `Sources/DevWifiBar/Views/SparklineView.swift`
- Modify: `Sources/DevWifiBar/BrandMark.swift` (drop the moved `BrandMarkView`)
- Modify: `Sources/DevWifiBar/Views/ProviderMark.swift` (import only)
- Modify: `Sources/DevWifiBar/MenuPanelView.swift`
- Modify: `Sources/DevWifiBar/Views/HeaderView.swift`
- Modify: `Sources/DevWifiBar/Views/FooterView.swift`
- Modify: `Sources/DevWifiBar/StatusBarController.swift`
- Modify: `Sources/DevWifiBar/Views/ProgressBar.swift`

**Interfaces:**
- Consumes: `Theme`, `BrandMarkView` from `DevWifiUI`.
- Produces: `AISection` is called with a new `quality:` argument (Task 7 defines it). `MenuPanelView` no longer passes `state` into `WidgetPickerView` (Task 8).

- [ ] **Step 1: Delete the app's copies and import the shared layer**

```bash
git rm Sources/DevWifiBar/Theme.swift Sources/DevWifiBar/Views/SparklineView.swift
```

`Theme` now lives in `Sources/DevWifiUI/Tokens.swift`; `SparklineView` and
`SignalMeter` live in `Sources/DevWifiUI/Charts.swift`. `Theme.teal` is gone
for good.

In `Sources/DevWifiBar/BrandMark.swift`, delete the whole
`struct BrandMarkView: View { ... }` at the bottom. Keep `enum BrandMark`
exactly as it is — it draws the menu bar `NSImage` through AppKit and must
stay in the app target.

Then add `import DevWifiUI` to every remaining file in `Sources/DevWifiBar`
that names `Theme`, `SparklineView` or `BrandMarkView`. That is this exact
list, and missing one is a compile error, not a silent bug:

```
BrandMark.swift          MenuPanelView.swift       PreviewExport.swift
Views/AISection.swift    Views/CombinedSection.swift
Views/FooterView.swift   Views/HeaderView.swift    Views/LatencySection.swift
Views/MetricSection.swift Views/NetworkSection.swift
Views/ProgressBar.swift  Views/ProviderMark.swift  Views/SignalSection.swift
Views/TrafficSection.swift Views/WidgetPickerView.swift
```

`ProviderMark.swift` is the easy one to miss: it uses `Theme.secondary` for its
fallback glyph and is not otherwise touched by this plan.

- [ ] **Step 2: Rewrite `Sources/DevWifiBar/MenuPanelView.swift`**

Keep `import AppKit` — the Quit action calls `NSApplication.shared.terminate`.

```swift
import AppKit
import DevWifiCore
import DevWifiUI
import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var layout: WidgetLayoutStore
    @State private var editingWidgets = false

    var body: some View {
        Group {
            if editingWidgets {
                WidgetPickerView(layout: layout) {
                    editingWidgets = false
                }
                .environment(\.colorScheme, .dark)
            } else {
                panel
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HeaderView(snapshot: state.snapshot)

            ForEach(layout.visible) { widget in
                widgetView(widget)
            }

            FooterView(
                launchAtLogin: $state.launchAtLoginEnabled,
                canManageLogin: LaunchAtLogin.isBundled,
                onLaunchAtLogin: { state.setLaunchAtLogin($0) },
                onWidgets: { editingWidgets = true },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        }
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth)
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func widgetView(_ widget: PanelWidget) -> some View {
        switch widget {
        case .signal:
            SignalSection(wifi: state.snapshot.wifi)
        case .traffic:
            TrafficSection(
                snapshot: state.snapshot,
                downloadHistory: state.downloadHistory,
                uploadHistory: state.uploadHistory
            )
        case .radar:
            AISection(
                traffic: state.aiTraffic,
                diagnosis: state.aiDiagnosis,
                quality: state.snapshot.wifi.quality,
                selectedApp: $state.selectedAIApp
            )
        case .network:
            NetworkSection(
                snapshot: state.snapshot,
                copiedField: state.copiedField,
                onCopy: { value, field in state.copy(value, field: field) }
            )
        case .latency:
            LatencySection(latencyMs: state.snapshot.latencyMs, history: state.latencyHistory)
        case .metric:
            MetricSection(wifi: state.snapshot.wifi)
        case .combined:
            CombinedSection(snapshot: state.snapshot, downloadHistory: state.downloadHistory)
        }
    }
}
```

Note the dividers are gone. The card is the separation.

If the existing file's property declarations at the top differ from the three shown here, keep the existing ones — only the `panel` and `widgetView` bodies and the removal of `divider` matter.

- [ ] **Step 3: Rewrite `Sources/DevWifiBar/Views/HeaderView.swift`**

```swift
import AppKit
import DevWifiCore
import DevWifiUI
import SwiftUI

@MainActor
struct HeaderView: View {
    let snapshot: NetworkSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HStack(alignment: .center, spacing: 10) {
                BrandMarkView(offline: !snapshot.wifi.powerOn, color: .primary)
                    .frame(width: 18, height: 18)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.wifi.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(detailLine)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(updatedText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            if needsLocation {
                LocationBanner()
            }
        }
    }

    private var detailLine: String {
        guard snapshot.wifi.powerOn else { return "Wi-Fi is off" }
        guard snapshot.wifi.connected else { return "Not connected" }
        var parts: [String] = []
        if let quality = snapshot.wifi.quality { parts.append(quality.rawValue) }
        if let rssi = snapshot.wifi.rssi { parts.append(Format.rssi(rssi).replacingOccurrences(of: "-", with: "\u{2212}")) }
        if let channel = snapshot.wifi.channel, channel > 0 { parts.append("ch \(channel)") }
        return parts.isEmpty ? "No signal" : parts.joined(separator: " \u{00B7} ")
    }

    private var updatedText: String {
        if snapshot.updatedAt.timeIntervalSince1970 == 0 {
            return "Waiting\u{2026}"
        }
        return Format.updated(from: snapshot.updatedAt).replacingOccurrences(of: "Updated ", with: "")
    }

    /// Without Location the SSID is hidden; everything else still works.
    private var needsLocation: Bool {
        snapshot.wifi.connected && snapshot.wifi.ssid == nil && !LocationGate.shared.isAuthorized
    }
}

/// App-only: opens System Settings. This is why the banner cannot live in DevWifiUI.
@MainActor
private struct LocationBanner: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Allow Location to show the network name. Everything else works without it.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Allow\u{2026}") {
                LocationGate.shared.requestIfNeeded()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.down.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}
```

The header now leads with the network name, not the product name. The product name is on the menu bar icon's tooltip already.

`\u{2212}` is the real minus sign. `Format.rssi` returns an ASCII hyphen, which renders too short beside monospaced digits.

- [ ] **Step 4: Rewrite the body of `Sources/DevWifiBar/Views/FooterView.swift`**

Change the imports to include `DevWifiUI`, then replace the `body` with:

```swift
    var body: some View {
        HStack(spacing: 6) {
            Toggle("Open at login", isOn: Binding(
                get: { launchAtLogin },
                set: { onLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 13))
            .disabled(!canManageLogin)
            .help(canManageLogin
                ? "Start \(ProductName.display) when you log in."
                : "Available after installing the .app")

            Spacer()

            Button("Widgets", action: onWidgets)
                .buttonStyle(.bordered)
                .controlSize(.regular)

            Button(action: onQuit) {
                HStack(spacing: 4) {
                    Text("Quit")
                    Text("\u{2318}Q").foregroundStyle(Theme.secondary)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 13))
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
```

Native button styles come back. The previous footer painted plain text teal to look like links.

- [ ] **Step 5: Force dark on the popover**

In `Sources/DevWifiBar/StatusBarController.swift`, inside `configurePopover()`, add one line after `popover.behavior = .transient`:

```swift
        popover.appearance = NSAppearance(named: .darkAqua)
```

- [ ] **Step 6: Repoint the default in `ProgressBar.swift`**

In `Sources/DevWifiBar/Views/ProgressBar.swift`, add `import DevWifiUI` and change the default colour:

```swift
    var color: Color = Theme.ok
```

- [ ] **Step 7: Build**

Run: `swift build`
Expected: FAILS, with "extra argument 'quality' in call" at the `AISection` call site in `MenuPanelView`. That is the expected state — Task 7 adds the parameter. To verify the rest of this task compiles, temporarily drop `quality: state.snapshot.wifi.quality,` from the call, confirm `swift build` succeeds, then put it back.

- [ ] **Step 8: Commit**

```bash
git add -A Sources/DevWifiBar
git commit -m "feat: lay the panel out as cards on a 360pt dark surface"
```

The app target now has a single source of tokens. `grep -rn 'Theme\.teal' Sources/`
must return nothing.

---

### Task 6: The six simple panel sections

Each card gets the shared container and semantic colour. No behaviour changes except Network, which becomes a real button with hover and press states.

**Files:**
- Modify: `Sources/DevWifiBar/Views/SignalSection.swift`
- Modify: `Sources/DevWifiBar/Views/MetricSection.swift`
- Modify: `Sources/DevWifiBar/Views/LatencySection.swift`
- Modify: `Sources/DevWifiBar/Views/TrafficSection.swift`
- Modify: `Sources/DevWifiBar/Views/CombinedSection.swift`
- Modify: `Sources/DevWifiBar/Views/NetworkSection.swift`

**Interfaces:**
- Consumes: `Theme`, `CardTitle`, `.card(padding:)`, `SparklineView`, `SignalMeter`, `StatusDot`, `RowButtonStyle` from `DevWifiUI`; `SignalQuality.segments` from Task 1.
- Produces: no new signatures. Call sites in `MenuPanelView` are unchanged.

Every file in this task starts with these three imports:

```swift
import DevWifiCore
import DevWifiUI
import SwiftUI
```

- [ ] **Step 1: Rewrite `SignalSection.swift`**

```swift
struct SignalSection: View {
    let wifi: WifiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: "Signal")
                Spacer()
                Text(Format.rssi(wifi.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
            }

            Text(wifi.quality?.rawValue ?? (wifi.powerOn ? "No signal" : "Wi-Fi off"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.color(for: wifi.quality))

            SignalMeter(filled: wifi.quality?.segments ?? 0, color: Theme.color(for: wifi.quality))

            HStack(alignment: .top) {
                detail("Channel", wifi.channel.map { $0 > 0 ? "\($0)" : "\u{2014}" } ?? "\u{2014}")
                detail("Radio rate", rateText)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(size: 13).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rateText: String {
        if let rate = wifi.transmitRateMbps, rate > 0 {
            return String(format: "%.0f Mbps", rate)
        }
        return "\u{2014}"
    }
}
```

- [ ] **Step 2: Rewrite `MetricSection.swift`**

```swift
/// Compact density: one number, the RSSI.
struct MetricSection: View {
    let wifi: WifiInfo

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                CardTitle(text: "Metric")
                Text(Format.rssi(wifi.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(for: wifi.quality))
            }
            Spacer()
            Text(wifi.quality?.rawValue ?? "No signal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.color(for: wifi.quality))
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 3: Rewrite `LatencySection.swift`**

```swift
struct LatencySection: View {
    let latencyMs: Double?
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: "Latency \u{00B7} 1.1.1.1")
                Spacer()
                Text(Format.latency(latencyMs))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(forLatency: latencyMs))
            }

            SparklineView(values: history, color: Theme.color(forLatency: latencyMs), peak: max(history.max() ?? 0, 60))
                .frame(height: 40)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
        }
        .card()
    }
}
```

The `peak: max(history.max() ?? 0, 60)` floor stops a flat 3ms line from filling the chart height and reading like a crisis.

- [ ] **Step 4: Rewrite `TrafficSection.swift`**

```swift
/// History: download and upload on one scale, current rates, session totals.
struct TrafficSection: View {
    let snapshot: NetworkSnapshot
    let downloadHistory: [Double]
    let uploadHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(text: "Traffic")
                Spacer()
                HStack(spacing: 10) {
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(uploadColor)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }

            ZStack {
                SparklineView(values: downloadHistory, color: Theme.down, peak: peak)
                SparklineView(values: uploadHistory, color: Theme.load, peak: peak)
            }
            .frame(height: 52)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.divider).frame(height: 1)
            }

            HStack {
                Text("This session")
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text("\u{2193} \(Format.bytes(snapshot.totalRx))   \u{2191} \(Format.bytes(snapshot.totalTx))")
                    .foregroundStyle(Theme.body)
            }
            .font(.system(size: 12).monospacedDigit())
        }
        .card()
    }

    private var peak: Double {
        max(downloadHistory.max() ?? 0, uploadHistory.max() ?? 0, 0.001)
    }

    private var uploadColor: Color {
        snapshot.uploadMbps >= AIBrief.saturateMbps ? Theme.load : .primary
    }
}
```

Both series share one `peak`, so the two lines are comparable. Drawing each against its own maximum would make a 0.2 Mbps upload look as tall as a 90 Mbps download.

- [ ] **Step 5: Rewrite `CombinedSection.swift`**

```swift
/// Dense density: signal, traffic and ping in one row.
struct CombinedSection: View {
    let snapshot: NetworkSnapshot
    let downloadHistory: [Double]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                StatusDot(color: Theme.color(for: snapshot.wifi.quality))
                Text(snapshot.wifi.quality?.rawValue ?? "No signal")
            }
            Spacer(minLength: 4)
            Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                .foregroundStyle(Theme.down)
            Spacer(minLength: 4)
            Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                .foregroundStyle(snapshot.uploadMbps >= AIBrief.saturateMbps ? Theme.load : .primary)
            Spacer(minLength: 4)
            Text(Format.latency(snapshot.latencyMs))
                .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))
        }
        .font(.system(size: 12, weight: .medium).monospacedDigit())
        .lineLimit(1)
        .card(padding: 10)
        .accessibilityElement(children: .combine)
    }
}
```

`downloadHistory` stays in the signature although the dense row no longer draws a sparkline — `MenuPanelView` passes it and the widget variant may use it. Do not remove the parameter.

- [ ] **Step 6: Rewrite `NetworkSection.swift`**

```swift
struct NetworkSection: View {
    let snapshot: NetworkSnapshot
    let copiedField: String?
    var onCopy: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(text: "Network")
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 4)

            row(title: "IP address", value: display(snapshot.localIP), field: "ip", copyValue: snapshot.localIP)
            row(title: "Gateway", value: display(snapshot.gateway), field: "gateway", copyValue: snapshot.gateway)
            row(title: "DNS", value: dnsText, field: "dns", copyValue: snapshot.dns.first?.address ?? "")
            row(title: "Latency to 1.1.1.1", value: Format.latency(snapshot.latencyMs), field: "latency", copyValue: nil)
        }
        .card(padding: 6)
    }

    private var dnsText: String {
        guard let server = snapshot.dns.first else { return "\u{2014}" }
        return server.provider == "Custom" ? server.address : "\(server.provider) \u{00B7} \(server.address)"
    }

    private func display(_ value: String) -> String {
        value.isEmpty ? "\u{2014}" : value
    }

    @ViewBuilder
    private func row(title: String, value: String, field: String, copyValue: String?) -> some View {
        let copied = copiedField == field
        let canCopy = !(copyValue ?? "").isEmpty
        Button {
            guard let copyValue, canCopy else { return }
            onCopy(copyValue, field)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 8)
                Text(copied ? "Copied" : value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(copied ? Theme.ok : .primary)
                    .lineLimit(1)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .disabled(!canCopy)
        .help(canCopy ? "Click to copy" : "")
    }
}
```

The row was an `onTapGesture` with no hover state, so nothing told the user it was clickable. It is now a real `Button`, disabled when there is nothing to copy.

- [ ] **Step 7: Build and run the tests**

Run: `swift build && make test`
Expected: build succeeds (with the temporary `quality:` workaround from Task 5 Step 7 still in place if Task 7 has not run), tests PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/DevWifiBar/Views
git commit -m "feat: give the six simple panel cards the shared container and semantic colour"
```

---

### Task 7: The radar card

The largest single rewrite. The card stops being a horizontal chip strip with a detail box below and becomes verdict-first: three evidence chips, the diagnosis in its semantic colour, then one row per app with a share bar. `AIAppStyle` — the per-vendor colour table — is deleted; a flow's colour now comes from the verdict, not from which company made the app.

**Files:**
- Modify: `Sources/DevWifiBar/Views/AISection.swift`

**Interfaces:**
- Consumes: `Theme`, `CardTitle`, `.card()`, `StatusDot`, `ChipTint`, `EvidenceChip`, `ShareBar` from `DevWifiUI`; `ProviderMark` from the app target.
- Produces: `AISection(traffic:diagnosis:quality:selectedApp:)` — the `quality:` parameter Task 5 already passes.

- [ ] **Step 1: Replace the whole file**

```swift
import DevWifiCore
import DevWifiUI
import SwiftUI

/// "On the link": the verdict, its three chips, and the AI apps using the link.
struct AISection: View {
    let traffic: AITrafficSnapshot
    let diagnosis: AIDiagnosis
    let quality: SignalQuality?
    @Binding var selectedApp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardTitle(text: "On the link")
                Spacer()
                if traffic.activeCount > 0 {
                    Text("\(traffic.activeCount) live")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .help("Process names and destinations only. No packet payloads.")

            if !diagnosis.evidence.isEmpty {
                HStack(spacing: 6) {
                    ForEach(diagnosis.evidence) { item in
                        EvidenceChip(label: item.label, value: item.value, tint: tint(for: item))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: diagnosis.kind))
                    Text(diagnosis.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color(for: diagnosis.kind))
                }
                Text(diagnosis.reason)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.body)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if !traffic.topFlows.isEmpty {
                VStack(spacing: 8) {
                    ForEach(traffic.topFlows) { flow in
                        AIAppRow(
                            flow: flow,
                            hasBandwidth: traffic.hasBandwidth,
                            share: share(of: flow),
                            barColor: diagnosis.kind == .saturated ? Theme.load : Color(white: 0.56),
                            selected: flow.app == selectedApp,
                            action: { selectedApp = flow.app }
                        )
                    }
                }
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
        .card()
    }

    /// Signal and Ping carry their own scales; anything else is only interesting when tripped.
    private func tint(for item: AIEvidence) -> ChipTint {
        switch item.label {
        case "Signal":
            return .semantic(Theme.color(for: quality))
        case "Ping":
            return .semantic(item.tripped ? Theme.load : Theme.ok)
        default:
            return item.tripped ? .semantic(Theme.load) : .neutral
        }
    }

    /// Upload share, scaled so a lone small flow does not fill the bar.
    private func share(of flow: AIFlow) -> Double {
        let total = traffic.topFlows.reduce(0) { $0 + ($1.uploadMbps ?? 0) }
        let scale = max(total, AIBrief.saturateMbps)
        return min(max((flow.uploadMbps ?? 0) / scale, 0.03), 1)
    }
}

private struct AIAppRow: View {
    let flow: AIFlow
    let hasBandwidth: Bool
    let share: Double
    let barColor: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ProviderMark(app: flow.app)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(flow.app)
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        Spacer(minLength: 8)
                        Text(rate)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.body)
                            .lineLimit(1)
                    }
                    if hasBandwidth {
                        ShareBar(share: share, color: barColor)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(flow.app), \(rate)")
    }

    private var rate: String {
        guard hasBandwidth, flow.uploadMbps != nil || flow.downloadMbps != nil else { return flow.detail }
        let up = String(format: "%.1f", flow.uploadMbps ?? 0)
        let down = String(format: "%.1f", flow.downloadMbps ?? 0)
        return "\(up) \u{2191}  \(down) \u{2193}"
    }
}
```

`enum AIAppStyle` is deleted with the rest of the old file. It is referenced
nowhere else in `Sources/` — verify with `grep -rn AIAppStyle Sources/`, which
must return nothing after this step.

- [ ] **Step 2: Restore the real call site**

If Task 5 Step 7 left `quality:` commented out or removed from the `AISection`
call in `MenuPanelView.swift`, put it back now:

```swift
            AISection(
                traffic: state.aiTraffic,
                diagnosis: state.aiDiagnosis,
                quality: state.snapshot.wifi.quality,
                selectedApp: $state.selectedAIApp
            )
```

- [ ] **Step 3: Build and test**

Run: `swift build && make test`
Expected: both succeed, with no temporary workarounds left in the tree.

- [ ] **Step 4: Commit**

```bash
git add Sources/DevWifiBar/Views/AISection.swift Sources/DevWifiBar/MenuPanelView.swift
git commit -m "feat: lead the radar card with the verdict and one row per app"
```

---

### Task 8: Widget picker, preview export and app wiring

The picker drops its gallery of live previews for a plain list of switches, which is what the control actually is. That removes its dependency on `AppState`, so `PreviewExport` must now be handed the layout store explicitly.

**Files:**
- Modify: `Sources/DevWifiBar/Views/WidgetPickerView.swift`
- Modify: `Sources/DevWifiBar/PreviewExport.swift`
- Modify: `Sources/DevWifiBar/DevWifiBarApp.swift`

**Interfaces:**
- Consumes: `Theme`, `.card(padding:)` from `DevWifiUI`.
- Produces: `PreviewExport.run(state:layout:directory:)` — note the new `layout` parameter.

- [ ] **Step 1: Replace `Sources/DevWifiBar/Views/WidgetPickerView.swift`**

```swift
import DevWifiCore
import DevWifiUI
import SwiftUI

/// Chooses which cards show in the panel. The same cards ship as desktop widgets.
struct WidgetPickerView: View {
    @ObservedObject var layout: WidgetLayoutStore
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            HStack(spacing: 6) {
                Button(action: onDone) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .keyboardShortcut(.cancelAction)

                Text("Widgets")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.defaultAction)
            }

            Text("Choose the cards in this panel.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element) { index, widget in
                    row(widget)
                    if index < order.count - 1 {
                        Rectangle().fill(Theme.divider).frame(height: 1)
                    }
                }
            }
            .card(padding: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text("On the desktop")
                    .font(.system(size: 13, weight: .semibold))
                Text("The same cards are desktop and Notification Center widgets: right-click the desktop \u{203A} Edit Widgets \u{203A} \(ProductName.display). macOS refreshes them about every five minutes. On the link fills in after \(ProductName.display) has saved its first snapshot.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.78))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        .padding(Theme.panelPadding)
        .frame(width: Theme.panelWidth)
        .background(Theme.background)
    }

    private var order: [PanelWidget] {
        [.metric, .signal, .traffic, .combined, .latency, .radar, .network]
    }

    private func row(_ widget: PanelWidget) -> some View {
        Toggle(isOn: Binding(
            get: { layout.isVisible(widget) },
            set: { layout.setVisible(widget, visible: $0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(widget.title)
                    .font(.system(size: 13))
                Text(widget.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Theme.control)
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 9)
    }
}
```

The `@EnvironmentObject private var state: AppState` line is gone along with
the previews, which is why `MenuPanelView` stopped passing it in Task 5. The
fixed 420pt `ScrollView` is gone too — seven switches fit without scrolling.

- [ ] **Step 2: Update `Sources/DevWifiBar/PreviewExport.swift`**

Add `import DevWifiUI`, then change the signature and the two bodies:

```swift
    static func run(state: AppState, layout: WidgetLayoutStore, directory: URL) async {
        try? await Task.sleep(for: .seconds(5))

        let panel = MenuPanelView()
            .environmentObject(state)
            .environmentObject(layout)
        write(panel, to: directory.appendingPathComponent("panel.png"), scale: 2)

        let mark = BrandMarkView(color: .white)
            .frame(width: 128, height: 128)
            .padding(24)
            .background(Theme.background)
```

Leave the rest of the function and the `write` helper unchanged.

`MenuPanelView` reads `layout` from the environment, so the export produced a
blank panel without it. The mark renders white because teal no longer exists.

- [ ] **Step 3: Update the call site in `Sources/DevWifiBar/DevWifiBarApp.swift`**

```swift
                await PreviewExport.run(state: state, layout: layout, directory: docs)
```

- [ ] **Step 4: Build and test**

Run: `swift build && make test`
Expected: both PASS.

- [ ] **Step 5: Check the panel by eye**

Run: `make package && open dist/Airtime.app`

Click the menu bar icon. Confirm: a 360pt dark panel of separated cards with no
divider lines between them; the header shows the network name with
`Quality \u{00B7} \u{2212}XX dBm \u{00B7} ch N` beneath it; no teal anywhere; the Widgets button
opens a list of switches; Quit shows `\u{2318}Q`.

- [ ] **Step 6: Commit**

```bash
git add Sources/DevWifiBar
git commit -m "feat: make the widget picker a list of switches"
```

---

### Task 9: Widget chrome on the shared primitives

Replaces `WidgetTheme.swift` — tokens, mark and sparkline all duplicated from the app — with a single `WidgetCard` container built on `DevWifiUI`. After this task the extension still builds but the seven views have not been rewritten, so they will fail to compile until Task 10. Tasks 9 and 10 therefore land as one commit.

**Files:**
- Delete: `Sources/DevWifiBarWidgets/WidgetTheme.swift`
- Create: `Sources/DevWifiBarWidgets/WidgetCard.swift`

**Interfaces:**
- Consumes: `Theme`, `CardTitle`, `BrandMarkView` from `DevWifiUI`.
- Produces: `WidgetCard(title:trailing:offline:content:)`.

- [ ] **Step 1: Delete the duplicated layer**

```bash
git rm Sources/DevWifiBarWidgets/WidgetTheme.swift
```

That file held `WidgetTheme` (a hand-copy of `Theme`), `WidgetBrandMark` (a
literal copy of `BrandMarkView`) and `WidgetSparkline` (a literal copy of the
old bar-chart `SparklineView`). All three now come from `DevWifiUI`.

- [ ] **Step 2: Create `Sources/DevWifiBarWidgets/WidgetCard.swift`**

```swift
import DevWifiUI
import SwiftUI

/// A widget's whole surface is one card: mark, title, optional trailing label,
/// then content. The dark background comes from `containerBackground` in each
/// widget's configuration.
struct WidgetCard<Content: View>: View {
    let title: String
    var trailing: String?
    var offline: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                BrandMarkView(offline: offline, color: .primary)
                    .frame(width: 14, height: 14)
                CardTitle(text: title)
                Spacer(minLength: 4)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
            content()
        }
        .padding(Theme.widgetPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }
}
```

The trailing label is now `Theme.secondary`, not an accent. In the old chrome
it was teal, which made every widget shout its least important text.

- [ ] **Step 3: Do not build yet**

The seven widget views still reference `WidgetTheme`, `WidgetChrome` and
`WidgetSparkline`. Go straight to Task 10 and build there.

---

### Task 10: The seven widget views

Each widget mirrors its panel card. Type sizes differ only where a `systemSmall` container forces it.

**Files:**
- Modify: `Sources/DevWifiBarWidgets/SignalWidget.swift`
- Modify: `Sources/DevWifiBarWidgets/MetricWidget.swift`
- Modify: `Sources/DevWifiBarWidgets/LatencyWidget.swift`
- Modify: `Sources/DevWifiBarWidgets/TrafficWidget.swift`
- Modify: `Sources/DevWifiBarWidgets/NetworkWidget.swift`
- Modify: `Sources/DevWifiBarWidgets/RadarWidget.swift`
- Modify: `Sources/DevWifiBarWidgets/CombinedWidget.swift`

**Interfaces:**
- Consumes: `WidgetCard` from Task 9; `Theme`, `SignalMeter`, `SparklineView`, `StatusDot` from `DevWifiUI`; `WidgetSnapshot.signalQuality` and `SignalQuality.segments` from Task 1.
- Produces: nothing other tasks depend on.

In every file below, the imports become:

```swift
import DevWifiCore
import DevWifiUI
import SwiftUI
import WidgetKit
```

and in every `StaticConfiguration` the background line becomes:

```swift
                .containerBackground(for: .widget) { Theme.background }
```

Keep each `Widget` struct's `kind` string, `configurationDisplayName`,
`description` and `supportedFamilies` exactly as they are. Changing a `kind`
orphans every widget a user has already placed on their desktop.

- [ ] **Step 1: `SignalWidget.swift` — replace `SignalWidgetView`**

```swift
struct SignalWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Signal", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 10) {
                Text(snapshot.signalQuality?.rawValue ?? (snapshot.powerOn ? "No signal" : "Wi-Fi off"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                SignalMeter(
                    filled: snapshot.signalQuality?.segments ?? 0,
                    color: Theme.color(for: snapshot.signalQuality)
                )

                HStack(alignment: .top) {
                    detail("Channel", snapshot.channel.map { $0 > 0 ? "\($0)" : "\u{2014}" } ?? "\u{2014}")
                    detail("RSSI", Format.rssi(snapshot.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(size: 12).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

The panel's Signal card pairs Channel with Radio rate. `WidgetSnapshot` does
not carry `transmitRateMbps`, so the widget pairs Channel with RSSI instead —
the one place a widget shows different *content*, not just a different size.
Do not add the field to `WidgetSnapshot` to close the gap: its stored shape is
frozen by the Global Constraints.

- [ ] **Step 2: `MetricWidget.swift` — replace `MetricWidgetView`**

```swift
struct MetricWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Metric", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Format.rssi(snapshot.rssi).replacingOccurrences(of: "-", with: "\u{2212}"))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                Text(snapshot.signalQuality?.rawValue ?? "No signal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.color(for: snapshot.signalQuality))
                Text(snapshot.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 3: `LatencyWidget.swift` — replace `LatencyWidgetView`**

```swift
struct LatencyWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Latency", trailing: "1.1.1.1", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Format.latency(snapshot.latencyMs))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))

                SparklineView(
                    values: snapshot.latencyHistory,
                    color: Theme.color(forLatency: snapshot.latencyMs),
                    peak: max(snapshot.latencyHistory.max() ?? 0, 60)
                )
                .frame(height: 28)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }
}
```

The panel sets the ping at 15pt because it labels a chart. Here it stays at
22pt: in a small widget the ping is the content.

- [ ] **Step 4: `TrafficWidget.swift` — replace `TrafficWidgetView`**

```swift
struct TrafficWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Traffic", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(uploadColor)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .lineLimit(1)

                ZStack {
                    SparklineView(values: snapshot.downloadHistory, color: Theme.down, peak: peak)
                    SparklineView(values: snapshot.uploadHistory, color: Theme.load, peak: peak)
                }
                .frame(height: family == .systemMedium ? 44 : 26)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.divider).frame(height: 1)
                }
            }
        }
    }

    private var peak: Double {
        max(snapshot.downloadHistory.max() ?? 0, snapshot.uploadHistory.max() ?? 0, 0.001)
    }

    private var uploadColor: Color {
        snapshot.uploadMbps >= AIBrief.saturateMbps ? Theme.load : .primary
    }
}
```

`uploadHistory` already travels in the snapshot and was being thrown away. The
second series costs nothing to draw.

- [ ] **Step 5: `NetworkWidget.swift` — replace `NetworkWidgetView`**

```swift
struct NetworkWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Network", trailing: snapshot.displayName, offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 7) {
                row("IP address", snapshot.localIP.isEmpty ? "\u{2014}" : snapshot.localIP)
                row("Gateway", snapshot.gateway.isEmpty ? "\u{2014}" : snapshot.gateway)
                row("DNS", snapshot.dns.isEmpty ? "\u{2014}" : snapshot.dns)
                row("Latency to 1.1.1.1", Format.latency(snapshot.latencyMs))
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
        }
    }
}
```

No hover state and no copy action: a widget is not interactive. The panel's
`provider \u{00B7} address` DNS formatting is not reproducible here because
`WidgetSnapshot.dns` is already a flattened `String`.

- [ ] **Step 6: `RadarWidget.swift` — replace `RadarWidgetView`**

```swift
struct RadarWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "On the link", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: snapshot.diagnosisKind))
                    Text(snapshot.diagnosisTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.color(for: snapshot.diagnosisKind))
                }

                Text(snapshot.diagnosisReason)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.body)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let app = snapshot.topApp {
                    Text(app)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
```

The verdict leads. Previously the app name led and the verdict was an
uppercase teal label in the corner, which read as decoration.
`diagnosisKind` was already in the snapshot and unused.

- [ ] **Step 7: `CombinedWidget.swift` — replace `CombinedWidgetView`**

```swift
struct CombinedWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        WidgetCard(title: "Combined", offline: !snapshot.powerOn) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    StatusDot(color: Theme.color(for: snapshot.signalQuality))
                    Text(snapshot.signalQuality?.rawValue ?? "No signal")
                    Spacer(minLength: 4)
                    Text("\u{2193} \(Format.mbps(snapshot.downloadMbps))")
                        .foregroundStyle(Theme.down)
                    Spacer(minLength: 4)
                    Text("\u{2191} \(Format.mbps(snapshot.uploadMbps))")
                        .foregroundStyle(snapshot.uploadMbps >= AIBrief.saturateMbps ? Theme.load : .primary)
                    Spacer(minLength: 4)
                    Text(Format.latency(snapshot.latencyMs))
                        .foregroundStyle(Theme.color(forLatency: snapshot.latencyMs))
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .lineLimit(1)

                SparklineView(values: snapshot.downloadHistory, color: Theme.down)
                    .frame(height: 30)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.divider).frame(height: 1)
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 8: Build the extension**

Run: `make widgets`
Expected: succeeds. Errors naming `WidgetTheme`, `WidgetChrome` or
`WidgetSparkline` mean a file was missed in Steps 1–7; those three symbols no
longer exist.

- [ ] **Step 9: Build the package and run the tests**

Run: `swift build && make test`
Expected: both PASS. The extension is not part of the SwiftPM build, so this
catches nothing from this task — run it anyway to confirm nothing regressed.

- [ ] **Step 10: Commit**

```bash
git add -A Sources/DevWifiBarWidgets
git commit -m "feat: put the widgets on the same cards and semantic colours as the panel"
```

---

### Task 11: Verify the system holds

No new behaviour. This task proves the redesign is complete and that the duplication is actually gone.

**Files:**
- Modify: `README.md` if it documents the teal accent or the 320pt panel.

- [ ] **Step 1: Prove teal is gone**

```bash
grep -rn "0.83" Sources/ ; grep -rni "teal" Sources/ README.md
```

Expected: no matches. Any hit is a surviving copy of the old accent.

- [ ] **Step 2: Prove the duplication is gone**

```bash
grep -rn "WidgetTheme\|WidgetBrandMark\|WidgetSparkline\|AIAppStyle" Sources/
ls Sources/DevWifiBar/Theme.swift Sources/DevWifiBar/Views/SparklineView.swift 2>&1
```

Expected: no symbol matches, and both files reported as missing.

- [ ] **Step 3: Prove one definition of each token**

```bash
grep -rn "panelWidth\|cardRadius\|static let ok\b" Sources/ | grep -v "Sources/DevWifiUI/Tokens.swift"
```

Expected: only call sites such as `Theme.panelWidth`, never a second
definition.

- [ ] **Step 4: Full build and test**

```bash
swift build && make test && make widgets
```

Expected: all three succeed.

- [ ] **Step 5: Check the widgets by eye**

```bash
make package && open dist/Airtime.app
```

Right-click the desktop, choose Edit Widgets, find Airtime and place all seven.
macOS refreshes them roughly every five minutes, so allow time or re-place a
widget to force a reload.

Confirm for each: dark card, no teal, the same type scale as the matching panel
card, and colour that tracks meaning — Signal's meter green when strong and red
when very weak, Latency orange above 80ms, Traffic's upload orange above
2.5 Mbps, Radar's dot matching its verdict.

- [ ] **Step 6: Update the README if it is now wrong**

Read `README.md` and correct any description of the teal accent, the 320pt
panel width, or the widget picker as a preview gallery. Change nothing else.

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: describe the redesigned panel and widgets"
```

If the README needed no change, skip the commit.

---

## Done when

- `swift build`, `make test` and `make widgets` all succeed.
- `grep -rni teal Sources/` returns nothing.
- `Theme` is defined once, in `Sources/DevWifiUI/Tokens.swift`.
- The panel and each widget show the same datum the same way at their own size.
