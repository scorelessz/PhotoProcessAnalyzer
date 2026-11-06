import SwiftUI

struct FindingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                card("控件 ID ↔ 处理函数") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow { h("按钮"); h("控件 ID"); h("分发机制"); h("处理函数") }
                        Divider()
                        ForEach(AppData.controlMap, id: \.0) { r in
                            GridRow { c(r.0); c(r.1, mono: true); c(r.2); c(r.3, mono: true) }
                        }
                    }
                }

                card("MFC 消息映射条目（0x599658）") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow { h("nMessage"); h("nID"); h("nSig"); h("pfn"); h("语义") }
                        Divider()
                        ForEach(AppData.messageMap, id: \.0) { r in
                            GridRow { c(r.0, mono: true); c(r.1, mono: true); c(r.2, mono: true); c(r.3, mono: true); c(r.4) }
                        }
                    }
                }

                card("ftol 扩框常量（.rdata 双精度）") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow { h("地址"); h("值"); h("作用") }
                        Divider()
                        ForEach(AppData.constants, id: \.0) { r in
                            GridRow { c(r.0, mono: true); c(r.1, mono: true); c(r.2) }
                        }
                    }
                }

                card("扩框公式") {
                    ForEach(AppData.formulas, id: \.self) { s in
                        Text(s).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 1000, alignment: .leading)
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
    }

    private func h(_ s: String) -> some View {
        Text(s).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }
    private func c(_ s: String, mono: Bool = false) -> some View {
        Text(s).font(mono ? .system(.caption, design: .monospaced) : .caption).textSelection(.enabled)
    }
}
