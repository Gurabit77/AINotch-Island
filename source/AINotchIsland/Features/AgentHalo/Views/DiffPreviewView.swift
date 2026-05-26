import SwiftUI

struct DiffPreviewView: View {
    let diff: AgentDiffContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fileHeader
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.hunks) { hunk in
                        ForEach(hunk.lines) { line in
                            diffLineView(line)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var fileHeader: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.system(size: 9))
            Text(diff.filePath.split(separator: "/").last.map(String.init) ?? diff.filePath)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
    }

    private func diffLineView(_ line: AgentDiffLine) -> some View {
        HStack(spacing: 0) {
            Text(linePrefix(line.type))
                .frame(width: 14, alignment: .center)
                .foregroundStyle(lineColor(line.type).opacity(0.7))

            if let num = line.lineNumber {
                Text("\(num)")
                    .frame(width: 28, alignment: .trailing)
                    .foregroundStyle(.white.opacity(0.3))
            } else {
                Spacer().frame(width: 28)
            }

            Text(" " + line.content)
                .lineLimit(1)
                .foregroundStyle(lineColor(line.type))
        }
        .font(.system(size: 9, design: .monospaced))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lineBackground(line.type))
    }

    private func linePrefix(_ type: AgentDiffLineType) -> String {
        switch type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        case .header: return "@"
        }
    }

    private func lineColor(_ type: AgentDiffLineType) -> Color {
        switch type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .white.opacity(0.7)
        case .header: return .cyan
        }
    }

    private func lineBackground(_ type: AgentDiffLineType) -> Color {
        switch type {
        case .addition: return .green.opacity(0.08)
        case .deletion: return .red.opacity(0.08)
        default: return .clear
        }
    }
}
