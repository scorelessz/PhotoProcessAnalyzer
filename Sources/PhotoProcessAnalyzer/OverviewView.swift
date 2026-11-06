import SwiftUI

struct OverviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                sectionCard("目标身份") {
                    keyValueRows(AppData.identity)
                }
                sectionCard("处理流水线") {
                    ForEach(Array(AppData.pipeline.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    }
                }
                sectionCard("输出机制（要点）") {
                    Text("保存 = cvSaveImage(≈95) → CImage quality=40 重编码 → 追加 10 字节标记\nFF 02 00 08 67 6A 67 77 79 32  (\"gjgwy2\")，疑为报名网站识别标记，可被伪造。")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("照片处理工具.exe")
                .font(.system(.largeTitle, design: .rounded).bold())
            Text("PhotoProcess 1.0.0.25 · 人社部人事考试中心 · 报名证件照预处理工具")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("本应用汇总 REA / Ghidra 12.1.4 的静态逆向分析结果（未执行样本）。")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }

    private func sectionCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
    }

    private func keyValueRows(_ pairs: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(pairs, id: \.0) { k, v in
                HStack(alignment: .top) {
                    Text(k).frame(width: 90, alignment: .trailing).foregroundStyle(.secondary)
                    Text(v).textSelection(.enabled)
                }
                .font(.system(.body, design: .monospaced))
            }
        }
    }
}
