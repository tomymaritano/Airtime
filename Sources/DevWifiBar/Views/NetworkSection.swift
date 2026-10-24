import DevWifiCore
import DevWifiUI
import SwiftUI

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
