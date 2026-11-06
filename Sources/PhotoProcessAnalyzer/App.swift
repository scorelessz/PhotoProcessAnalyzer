import SwiftUI

@main
struct PhotoProcessAnalyzerApp: App {
    var body: some Scene {
        WindowGroup("照片处理工具 · 逆向分析") {
            ContentView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1120, height: 780)
        .windowStyle(.automatic)
    }
}
