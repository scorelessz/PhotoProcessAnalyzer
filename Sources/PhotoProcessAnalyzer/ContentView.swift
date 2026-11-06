import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case process = "照片处理"
    case about = "关于本应用"
    case overview = "概览"
    case report = "逆向分析报告"
    case findings = "消息映射与常量"
    case resources = "资源文件"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .process: return "wand.and.stars"
        case .about: return "info.circle"
        case .overview: return "gearshape.2"
        case .report: return "doc.text"
        case .findings: return "function"
        case .resources: return "photo.on.rectangle"
        }
    }

    /// 一级菜单：照片处理 + 关于本应用
    var isPrimary: Bool { self == .process || self == .about }
}

struct ContentView: View {
    @State private var selection: AppSection? = .process

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                SwiftUI.Section {
                    ForEach(AppSection.allCases.filter(\.isPrimary)) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
                SwiftUI.Section("专业信息") {
                    ForEach(AppSection.allCases.filter { !$0.isPrimary }) { s in
                        Label(s.rawValue, systemImage: s.icon).tag(s)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            switch selection ?? .process {
            case .process: ProcessView()
            case .about: AboutView()
            case .overview: OverviewView()
            case .report: ReportView()
            case .findings: FindingsView()
            case .resources: ResourcesView()
            }
        }
        .navigationTitle("照片处理工具 · 逆向分析")
    }
}
