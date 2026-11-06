import SwiftUI
import AppKit

struct ProcessView: View {
    @State private var original: CGImage?
    @State private var output: CGImage?
    @State private var status: String = "点击「打开照片文件」选择一张 JPG 证件照。"
    @State private var isError = false
    @State private var isProcessing = false
    @State private var lastURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                statusBar
                previews
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 按钮区

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                openPhoto()
            } label: {
                Label("打开照片文件", systemImage: "folder")
            }
            .keyboardShortcut("o", modifiers: .command)

            Button {
                savePhoto()
            } label: {
                Label("保存照片文件", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(output == nil)

            if isProcessing {
                ProgressView().controlSize(.small)
            }
        }
        .controlSize(.large)
    }

    private var statusBar: some View {
        Text(status)
            .font(.callout)
            .foregroundStyle(isError ? Color.red : Color.primary)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(isError ? Color.red.opacity(0.08) : Color.gray.opacity(0.08)))
    }

    // MARK: 预览

    private var previews: some View {
        HStack(alignment: .top, spacing: 16) {
            imagePanel("原始照片", original)
            imagePanel("处理后（295 × 413）", output)
        }
    }

    private func imagePanel(_ title: String, _ img: CGImage?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let img {
                Image(nsImage: NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height)))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 340, maxHeight: 480)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.08))
                    .frame(width: 220, height: 300)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary))
            }
        }
    }

    // MARK: 打开 / 保存

    private func openPhoto() {
        let panel = NSOpenPanel()
        panel.title = "打开照片文件"
        panel.allowedContentTypes = [.jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isProcessing = true
        defer { isProcessing = false }

        switch PhotoProcessor.process(url: url) {
        case .success(let r):
            original = r.original
            output = r.output
            lastURL = url
            isError = false
            status = "处理成功：已裁剪人脸并缩放至 \(r.output.width)×\(r.output.height)，可保存（约 10 KB，默认文件名 报名照片.jpg）。"
        case .failure(let e):
            original = nil
            output = nil
            isError = true
            status = e.localizedDescription
        }
    }

    private func savePhoto() {
        guard let output else { return }
        let panel = NSSavePanel()
        panel.title = "保存照片文件"
        panel.nameFieldStringValue = "报名照片.jpg"
        panel.allowedContentTypes = [.jpeg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try PhotoProcessor.save(output, to: url)
            isError = false
            status = "照片已保存成功：\(url.path)（含处理标记）"
        } catch {
            isError = true
            status = "保存失败：\(error.localizedDescription)"
        }
    }
}
