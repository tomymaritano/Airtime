import DevWifiCore
import SwiftUI

struct NetworkSection: View {
    let snapshot: NetworkSnapshot
    let copiedField: String?
    var onCopy: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)

            row(title: "IP", value: display(snapshot.localIP), field: "ip", copyValue: snapshot.localIP)
            row(title: "Gateway", value: display(snapshot.gateway), field: "gateway", copyValue: snapshot.gateway)
            row(title: "DNS", value: dnsText, field: "dns", copyValue: snapshot.dns.first?.address ?? "")
            row(title: "Latency", value: Format.latency(snapshot.latencyMs), field: "latency", copyValue: nil)
        }
    }

    private var dnsText: String {
        guard let line = snapshot.dns.first?.line, !line.isEmpty else { return "—" }
        return line
    }

    private func display(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }

    private func row(title: String, value: String, field: String, copyValue: String?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.secondary)
            Spacer()
            Text(copiedField == field ? "Copied" : value)
                .monospacedDigit()
                .foregroundStyle(copiedField == field ? Theme.teal : .primary)
        }
        .font(.system(size: 11))
        .contentShape(Rectangle())
        .onTapGesture {
            guard let copyValue, !copyValue.isEmpty else { return }
            onCopy(copyValue, field)
        }
        .accessibilityAddTraits(copyValue == nil ? [] : .isButton)
    }
}
