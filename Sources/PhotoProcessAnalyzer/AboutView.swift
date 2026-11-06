import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                card("它能做什么", "info.circle") {
                    bullet("把报名证件照（JPG）自动处理成符合考试报名要求的 295×413 标准照片（约 10 KB）")
                    bullet("自动校验：格式、尺寸、人脸、背景颜色、头部比例")
                    bullet("按人脸自动裁剪并缩放，保存时附加处理标记")
                }
                card("怎么用", "hand.tap") {
                    step("1", "点击「打开照片文件」，选择一张 JPG 证件照")
                    step("2", "符合要求时，右侧显示处理后的 295×413 预览")
                    step("3", "点击「保存照片文件」导出（默认文件名：报名照片.jpg）")
                }
                card("照片要求", "checkmark.seal") {
                    bullet("JPG/JPEG 格式，白底或蓝底")
                    bullet("宽不低于 295 像素、高不低于 413 像素")
                    bullet("正面免冠人像，不得美化修饰")
                }
                Text("本应用是基于逆向工程还原的 macOS 版复刻；处理流水线的阈值与原程序一致。更多技术细节见左侧「专业信息」。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("照片处理工具")
                .font(.system(.largeTitle, design: .rounded).bold())
            Text("报名证件照预处理 · macOS 原生版")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func card(_ title: String, _ icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
        }
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(n)
                .font(.caption.bold())
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            Text(text)
        }
    }
}
