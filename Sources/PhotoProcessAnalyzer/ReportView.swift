import SwiftUI

struct ReportView: View {
    private let main = ResourceLoader.text("report_main") ?? "报告加载失败"
    private let supplement = ResourceLoader.text("report_supplement") ?? ""

    var body: some View {
        TabView {
            MarkdownView(main)
                .tabItem { Label("主报告", systemImage: "doc.text") }
            if !supplement.isEmpty {
                MarkdownView(supplement)
                    .tabItem { Label("补充报告", systemImage: "doc.text.append") }
            }
        }
    }
}
