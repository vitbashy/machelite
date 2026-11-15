import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var log: DiagnosticsLog

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent requests and raw model responses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy All") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(log.plainText, forType: .string)
                }
                .controlSize(.small)
                .disabled(log.entries.isEmpty)
                Button("Clear") { log.clear() }
                    .controlSize(.small)
                    .disabled(log.entries.isEmpty)
            }
            .padding(10)

            Divider()

            if log.entries.isEmpty {
                Spacer()
                Text("Nothing logged yet.")
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(log.entries) { entry in
                            EntryRow(entry: entry)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct EntryRow: View {
    let entry: DiagnosticEntry

    private var tint: Color {
        switch entry.category {
        case .request:  return .secondary
        case .response: return .accentColor
        case .failure:  return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entry.category.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Text(entry.summary)
                .font(.system(size: 12))
            if let detail = entry.detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.08)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
