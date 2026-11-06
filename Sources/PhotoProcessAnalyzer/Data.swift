import Foundation

// MARK: - Resource loading

enum ResourceLoader {
    /// Resolve a resource by its full file name (e.g. "BITMAP_id138_lang2052.bmp").
    static func url(named filename: String) -> URL? {
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension
        for b in [Bundle.main, Bundle.module] {
            if let u = b.url(forResource: base, withExtension: ext) { return u }
        }
        // SPM flattening may leave files under an "extracted" subdir in a hand-built bundle.
        for sub in ["extracted", "Resources"] {
            if let u = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: sub) { return u }
        }
        return nil
    }

    static func text(_ name: String) -> String? {
        guard let u = url(named: name + ".md") else { return nil }
        return try? String(contentsOf: u, encoding: .utf8)
    }

    static func json(_ name: String) -> Data? {
        guard let u = url(named: name + ".json") else { return nil }
        return try? Data(contentsOf: u)
    }
}

// MARK: - Extracted-resource manifest

struct ExtractedResource: Codable, Identifiable, Hashable {
    let file: String
    let type: String
    let resourceId: Int
    let lang: Int
    let offset: Int
    let size: Int
    let codepage: Int
    let sha256: String

    var id: String { file }

    var isImage: Bool { type == "BITMAP" || type == "ICON" || type == "GROUP_ICON" }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case file, type, lang, offset, size, codepage, sha256
        case resourceId = "id"
    }
}

struct Manifest: Codable {
    let source_sha256: String
    let source_bytes: Int
    let resources: [ExtractedResource]
}

enum AppData {
    static let manifest: Manifest = {
        if let d = ResourceLoader.json("manifest"),
           let m = try? JSONDecoder().decode(Manifest.self, from: d) {
            return m
        }
        return Manifest(source_sha256: "-", source_bytes: 0, resources: [])
    }()

    static let targetSHA256 = "e344fc1b4619d355d88a52bc1eddf216cca60fb55c8e9bab42ac5d4ed04183a9"
    static let targetBytes = 9_940_992

    // MARK: - Key facts (observed)
    static let identity: [(String, String)] = [
        ("产品名", "PhotoProcess 1.0.0.25（PhotoProcess.EXE）"),
        ("公司", "人社部人事考试中心（版权 2023；关于框遗留 2014）"),
        ("目标文件", "照片处理工具.exe"),
        ("SHA-256", "e344fc1b4619d355d88a52bc1eddf216cca60fb55c8e9bab42ac5d4ed04183a9"),
        ("格式", "PE32 / i386 / GUI，镜像基址 0x400000，3843 个函数"),
        ("构建", "MFC 4.2 + MSVC6 工具链 + OpenCV 1.0；Debug 构建（依赖 MSVCRTD.dll）"),
    ]

    static let pipeline: [String] = [
        "① 只读前 2 字节校验 JPEG SOI（FFD8）",
        "② 读 photo.ini 16 个阈值（缺省回落到内置默认值）",
        "③ 宽 < 295 或 高 < 413 → 拒绝（码 2）",
        "④ 3 个 3×3 背景采样点 RGB→HSV，须全为白/蓝/红 → 否则拒绝（码 3）",
        "⑤ Haar 正脸检测（haarcascade_frontalface_alt2.xml）→ 无人脸拒绝（码 5）",
        "⑥ 取最大人脸，要求 人脸宽/图宽 ≥ 0.32",
        "⑦ 按黄金比横向扩框、按 295:413 纵向跟随、校验留白 → 否则拒绝（码 4）",
        "⑧ cvResize 输出 295×413，合成进 interface00.bmp 预览",
        "保存：cvSaveImage(≈95) → CImage quality=40 重编码 → 追加 10 字节标记 FF 02 00 08 \"gjgwy2\"",
    ]

    // MARK: - Message map (observed)
    static let messageMap = [
        ("0x112 WM_SYSCOMMAND", "0", "0x12", "0x402ac0", "OnSysCommand"),
        ("0x00F WM_PAINT", "0", "0x0C", "0x402b40", "OnPaint"),
        ("0x037 WM_QUERYDRAGICON", "0", "0x23", "0x402c00", "返回成员 +0x224 图标"),
        ("0x111 WM_COMMAND", "ID 3", "0x0C", "0x403010", "保存照片文件"),
        ("0x084 WM_NCHITTEST", "0", "0x22", "0x4032b0", "OnNcHitTest"),
    ]

    static let controlMap = [
        ("打开照片文件", "1 (IDOK)", "基类 ON_COMMAND(IDOK, OnOK) → 虚调用", "OnOK = 0x402c10"),
        ("保存照片文件", "3", "本类 ON_COMMAND(3, …)", "0x403010"),
        ("退出操作", "2 (IDCANCEL)", "基类 ON_COMMAND(IDCANCEL, OnCancel)", "CDialog::OnCancel（未重写）"),
    ]

    // MARK: - ftol constants (observed)
    static let constants = [
        ("0x599540", "0.32", "人脸宽/图宽 最低阈值"),
        ("0x599538", "1.6181229773462784", "横向扩框系数 ≈ 黄金比 φ"),
        ("0x599530", "0.9", "裁剪宽高比校正下界"),
        ("0x599528", "1.1", "裁剪宽高比校正上界"),
        ("0x599518", "0.5", "高度四舍五入常数"),
    ]

    static let formulas: [String] = [
        "裁剪框宽 = trunc( 人脸宽 × 1.6181229773462784 )",
        "裁剪框高 = round( 裁剪框宽 × dst_height / dst_width )",
        "默认 dst_height/dst_width = 413/295 ≈ 1.4",
    ]
}
