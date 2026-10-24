# Airtime — one design system across panel, widgets and mark

Date: 2026-10-24
Status: approved, ready for implementation planning

## Problem

The menu bar panel redesign (patch `416275ca`, authored in session
`cse_01NXUr9dWT6HVBxyuLdnmeAq`) exists only as a patch file. It is not in
`main`, not in any branch, not in any local commit. It redesigns the panel and
nothing else.

Applying it alone would split the app in two. The panel would drop the teal
brand colour for macOS system colours used semantically; the seven desktop
widgets would keep teal, bar sparklines and `ProgressView`. The same datum —
signal quality, say — would render two different ways depending on where the
user looked.

The split is not an accident of this patch. Four concepts are already
duplicated by hand across the two targets:

| Concept    | App target          | Widget target     | Relationship   |
| ---------- | ------------------- | ----------------- | -------------- |
| Tokens     | `Theme`             | `WidgetTheme`     | copied by hand |
| Mark       | `BrandMarkView`     | `WidgetBrandMark` | literal copy   |
| Sparkline  | `SparklineView`     | `WidgetSparkline` | literal copy   |
| Container  | `.card()` (new)     | `WidgetChrome`    | diverged       |

That duplication is why teal survived on one side when it died on the other.
Fixing only the left-hand column leaves the mechanism in place.

## Goals

1. Apply the panel redesign.
2. Bring the seven widgets and the brand mark onto the same patterns.
3. Remove the duplication so the next change cannot desynchronise them.

## Non-goals

- Light mode. Airtime stays dark everywhere (decided below).
- New data. Every pattern here is served by fields `WidgetSnapshot` already
  carries.
- Reopening the panel's own layout decisions. The patch's content choices
  stand.

## Decisions taken

**Dark everywhere, fixed.** The panel can force dark (`popover.appearance =
.darkAqua`) because it is Airtime's own window. A desktop widget cannot — macOS
renders it beside Calendar and Weather, which follow the system appearance.
Airtime's widgets will stay dark in light mode, reading as a dark rectangle
among light ones. Accepted: Airtime is a developer tool, visual consistency
with itself beats integration with the desktop, and it keeps tokens as literal
hex rather than system colours that resolve per appearance.

The five semantic colours in the patch are the *dark* variants of Apple's
system colours. On a light background `#30D158` measures roughly 1.8:1 — this
decision is what makes them safe to hardcode.

**A shared SwiftUI target.** Tokens and primitives move to a new `DevWifiUI`
target rather than into `DevWifiCore` or staying duplicated. `DevWifiCore` is
deliberately SwiftUI-free and is the only target the app and the extension
share today; adding SwiftUI to it would pull the framework into the test target
and would still leave the views duplicated, since SwiftUI primitives sitting in
a logic module invite a second copy.

## Architecture

```
DevWifiCore   (logic, no SwiftUI)        unchanged
     ^
DevWifiUI     (tokens + primitives)      new
     ^                    ^
DevWifiBar          DevWifiBarWidgets
```

`DevWifiUI` is a SwiftPM target depending on `DevWifiCore`, exposed as a
`.library` product so XcodeGen can reach it from the extension target. The app
target gains the dependency in `Package.swift`; the widget target gains it in
`project.yml`.

### What lives in DevWifiUI

| File                 | Contents                                                        |
| -------------------- | --------------------------------------------------------------- |
| `Tokens.swift`       | public `Theme`: surfaces, text, semantics, metrics, `color(for:)` |
| `Card.swift`         | `CardTitle`, `CardBackground`, `.card(padding:)`                 |
| `Charts.swift`       | `SparklineView` (line, `peak:`), `SignalMeter`, `ShareBar`       |
| `Atoms.swift`        | `StatusDot`, `EvidenceChip`, `RowButtonStyle`, `HoverRow`        |
| `BrandMarkView.swift`| moved from the app target                                        |

Every symbol is `public`.

### What stays in DevWifiBar

`BrandMark` (the AppKit `NSImage` for the menu bar), `LocationBanner` (uses
`NSWorkspace`), and all `*Section` views.

### What is deleted

`WidgetTheme`, `WidgetBrandMark`, `WidgetSparkline`.

### Why the boundary holds

The widget target builds with `APPLICATION_EXTENSION_API_ONLY: YES`. Anything
app-only that leaks into `DevWifiUI` fails that build. The constraint is the
enforcement mechanism, not a side effect.

## Tokens

The patch's values, verbatim, plus `widgetPadding = 14` for the widget
container.

Surfaces: `background #1C1C1E`, `card #2A2A2D`, `divider` white 8%,
`hairline` white 12%.
Text: `body #D1D1D6`, `secondary #98989F`, `.primary`.
Semantic: `ok #30D158`, `load #FF9F0A`, `down #6AB4FF`, `bad #FF6961`,
`control #0A64D8`.
Metrics: `panelWidth 360`, `panelPadding 12`, `cardSpacing 8`,
`cardPadding 12`, `cardRadius 10`, `widgetPadding 14`.

Colour is derived from meaning, never hardcoded at a call site:
`color(for: SignalQuality?)`, `color(forLatency:)`,
`color(for: AIDiagnosisKind)`, `SignalQuality.segments`.

### Two corrections to the patch

`EvidenceChip` selects its background by comparing `tint == .primary`. Equality
on `Color` is fragile and hides the intent. Replace with an explicit
`ChipTint { case neutral, semantic(Color) }`.

`color(for: .fair)` returns `.primary`. Keep it, documented: fair is neither
good nor bad, and the absence of colour is the signal. In this system colour
means "look at this".

## Panel

Apply the patch, importing from `DevWifiUI` instead of defining `Theme` and the
primitives locally. `WidgetPickerView` no longer reads `state` — the patch
removes the live gallery previews — so dropping its `environmentObject` is
correct and not an oversight.

## Widgets

Each widget mirrors its panel section. This is the property being bought: a
widget and its card are the same design at two sizes.

| Widget   | Becomes                                                                       |
| -------- | ----------------------------------------------------------------------------- |
| Signal   | `SignalMeter` 5 segments, quality 15pt in `color(for:)`, channel/RSSI pair 12pt |
| Metric   | RSSI 22pt in `color(for:)`, quality 13pt trailing                             |
| Latency  | value 22pt in `color(forLatency:)`, line sparkline `peak: max(max, 60)`, hairline |
| Traffic  | two series in a `ZStack` on a shared peak — RX `down`, TX `load`              |
| Network  | key/value rows, mono values, `secondary` labels; no hover (not interactive)   |
| Radar    | `StatusDot` in `color(for: diagnosisKind)`, verdict first, reason after       |
| Combined | dense row: dot + quality, down, up, ping, each in its semantic colour         |

`uploadHistory` and `diagnosisKind` already travel in `WidgetSnapshot` and are
currently ignored. Most of this redesign spends information the app already
pays for.

The Signal widget is the one place the *content* differs, not just the size:
the panel pairs Channel with Radio rate, but `WidgetSnapshot` does not carry
`transmitRateMbps`, so the widget pairs Channel with RSSI. The field is not
added — the snapshot's stored shape is frozen by the App Group constraint
above.

Type sizes differ from the matching panel card where the family demands it. A
`systemSmall` widget is about 170pt wide, so Signal drops the panel's 17pt
quality headline to 15pt to clear room for the meter, and Latency keeps its
existing 22pt hero number rather than the panel's 15pt — in a small widget the
ping *is* the content, whereas in the panel it labels a chart. Everything else
matches the panel exactly.

### The SignalQuality accessor

`WidgetSnapshot.quality` is `String?`, so widgets cannot call
`Theme.color(for:)` or `.segments`. Add to `DevWifiCore`:

```swift
public var signalQuality: SignalQuality? {
    quality.flatMap(SignalQuality.init(rawValue:))
}
```

Computed, so `Codable` is untouched. This matters beyond tidiness:
`WidgetSnapshot` is persisted in an App Group shared by the app and the
extension. Changing the stored type would break reads during any window in
which two versions coexist.

### Forced dark

Each widget view carries `.environment(\.colorScheme, .dark)`, since
`containerBackground` is dark and the appearance decision above is fixed.

## Brand

`BrandMarkView` moves to `DevWifiUI`; `WidgetBrandMark` is deleted.
`BrandMark.menuBarImage` is unchanged — it already draws in black with
`isTemplate = true`, so macOS recolours it and it never carried teal. In
`PreviewExport` the mark renders white on `Theme.background`.

## Verification

Existing `DevWifiCoreTests` are logic-only and must keep passing.

New tests:
- `SignalQuality.segments` maps excellent…veryWeak to 5…1.
- `WidgetSnapshot.signalQuality` round-trips from `rawValue`, and returns `nil`
  for an unknown string.

Build verification:
- `swift build` for the package.
- `xcodegen` then `xcodebuild` for the widget extension. This is the real guard
  on the shared layer staying extension-safe.

Visual verification has no automated test. `PreviewExport` renders `panel.png`,
which covers the panel but not the widgets; the widgets need eyes.

## Risks

Regenerating the Xcode project: `project.yml` pins `projectFormat:
xcode15_3` because CI runs Xcode 15.4 on `macos-14`, which cannot open
objectVersion 77. The new product dependency must not change that pin.

The patch arrived as pasted text. It will be applied as file edits, not
`git apply` — one stray space rejects the whole patch, and the content is known
good independent of its exact whitespace.
