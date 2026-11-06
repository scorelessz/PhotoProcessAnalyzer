import SwiftUI

enum MDBlock {
    case heading(Int, String)
    case paragraph(String)
    case code(String)
    case list(String)
    case table(String)
}

enum Markdown {
    static func parse(_ text: String) -> [MDBlock] {
        var blocks: [MDBlock] = []
        var codeBuf: [String] = []
        var inCode = false
        var para: [String] = []
        var listBuf: [String] = []
        var tableBuf: [String] = []

        func flushPara() {
            if !para.isEmpty { blocks.append(.paragraph(para.joined(separator: " "))); para.removeAll() }
        }
        func flushList() {
            for it in listBuf { blocks.append(.list(it)) }
            listBuf.removeAll()
        }
        func flushTable() {
            if !tableBuf.isEmpty { blocks.append(.table(tableBuf.joined(separator: "\n"))); tableBuf.removeAll() }
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeBuf.joined(separator: "\n")))
                    codeBuf.removeAll(); inCode = false
                } else {
                    flushPara(); flushList(); flushTable(); inCode = true
                }
                continue
            }
            if inCode { codeBuf.append(raw); continue }

            if line.hasPrefix("#") {
                flushPara(); flushList(); flushTable()
                var lvl = 0; var rest = line
                while rest.first == "#" { lvl += 1; rest.removeFirst() }
                blocks.append(.heading(min(lvl, 6), rest.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushPara(); flushTable()
                listBuf.append(String(line.dropFirst(2)))
            } else if line.hasPrefix("|") {
                flushPara(); flushList()
                tableBuf.append(line)
            } else if line.isEmpty {
                flushPara(); flushList(); flushTable()
            } else {
                flushList(); flushTable()
                para.append(line)
            }
        }
        if inCode { blocks.append(.code(codeBuf.joined(separator: "\n"))) }
        flushPara(); flushList(); flushTable()
        return blocks
    }
}

struct MarkdownView: View {
    let text: String
    let monospaced: Bool

    init(_ text: String, monospaced: Bool = false) {
        self.text = text
        self.monospaced = monospaced
    }

    var body: some View {
        let blocks = Markdown.parse(text)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MDBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            let size: Font = level <= 1 ? .system(.title, design: .rounded).bold()
                : level == 2 ? .system(.title2, design: .rounded).bold()
                : .system(.title3, design: .rounded).bold()
            Text(text).font(size).textSelection(.enabled)

        case .paragraph(let str):
            if monospaced {
                Text(str).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            } else {
                (try? Text(AttributedString(markdown: str, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))))
                    .map { $0.textSelection(.enabled) }
                    ?? Text(str).textSelection(.enabled)
            }

        case .code(let str):
            Text(str)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)))
                .textSelection(.enabled)

        case .list(let str):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                (try? Text(AttributedString(markdown: str, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))))
                    .map { $0.textSelection(.enabled) }
                    ?? Text(str).textSelection(.enabled)
            }

        case .table(let str):
            Text(str)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.06)))
                .textSelection(.enabled)
        }
    }
}
