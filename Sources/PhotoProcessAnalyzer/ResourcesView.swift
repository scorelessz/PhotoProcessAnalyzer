import SwiftUI

struct ResourcesView: View {
    private let manifest = AppData.manifest
    @State private var selection: ExtractedResource.ID?

    var body: some View {
        HSplitView {
            resourceList
                .frame(minWidth: 340, idealWidth: 420, maxWidth: 560)
            preview
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resourceList: some View {
        List(manifest.resources, selection: $selection) { r in
            VStack(alignment: .leading, spacing: 2) {
                Text(r.file).font(.system(.callout, design: .monospaced))
                HStack(spacing: 8) {
                    Text(r.type).font(.caption2).foregroundStyle(.blue)
                    Text(r.displaySize).font(.caption2).foregroundStyle(.secondary)
                    Text(r.sha256.prefix(12)).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var preview: some View {
        if let r = manifest.resources.first(where: { $0.id == selection }) {
            VStack(spacing: 12) {
                if r.isImage, let img = loadImage(r) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 640, maxHeight: 640)
                        .background(Color.black.opacity(0.04))
                } else {
                    ContentUnavailableView("无预览", systemImage: "doc.badge.ellipsis",
                                           description: Text("该资源为二进制/文本，无图像预览。"))
                }
                Divider()
                detailGrid(r)
            }
            .padding(16)
        } else {
            ContentUnavailableView("选择左侧资源查看详情", systemImage: "photo.on.rectangle")
        }
    }

    private func loadImage(_ r: ExtractedResource) -> NSImage? {
        guard let u = ResourceLoader.url(named: r.file) else { return nil }
        return NSImage(contentsOf: u)
    }

    private func detailGrid(_ r: ExtractedResource) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            row("类型", r.type)
            row("资源 ID", String(r.resourceId))
            row("语言", String(r.lang))
            row("大小", r.displaySize)
            row("SHA-256", r.sha256)
            row("文件偏移", String(r.offset))
            row("代码页", String(r.codepage))
        }
        .font(.system(.caption, design: .monospaced))
    }

    private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(.secondary)
            Text(v).textSelection(.enabled)
        }
    }
}
