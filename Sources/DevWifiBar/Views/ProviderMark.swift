import AppKit
import DevWifiUI
import SwiftUI

/// Official Simple Icons marks, loaded from bundled SVGs/PNGs — not hand-drawn paths.
struct ProviderMark: View {
    let app: String

    var body: some View {
        Group {
            if let image = Self.image(for: app) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.secondary)
            }
        }
        .accessibilityHidden(true)
    }

    static func image(for app: String) -> NSImage? {
        guard let slug = slug(for: app) else { return nil }
        for bundle in iconBundles {
            if let url = bundle.url(forResource: slug, withExtension: "png", subdirectory: "Providers")
                ?? bundle.url(forResource: slug, withExtension: "png"),
               let image = NSImage(contentsOf: url)
            {
                image.isTemplate = true
                return image
            }
        }
        return nil

    }

    private static var iconBundles: [Bundle] {
        var bundles = [Bundle.main]
        #if SWIFT_PACKAGE
        bundles.insert(Bundle.module, at: 0)
        #endif
        return bundles
    }

    static func slug(for app: String) -> String? {
        switch app {
        case "Cursor": return "cursor"
        case "Claude": return "claude"
        case "Grok": return "x"
        case "ChatGPT", "OpenAI": return "openai"
        case "Gemini": return "googlegemini"
        case "Copilot": return "githubcopilot"
        case "Windsurf": return "windsurf"
        case "Ollama": return "ollama"
        case "Perplexity": return "perplexity"
        case "Anthropic": return "anthropic"
        default: return nil
        }
    }
}
