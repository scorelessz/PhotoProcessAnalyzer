import Foundation
import AppKit
import Vision
import ImageIO
import UniformTypeIdentifiers

// MARK: - 配置（来自逆向：photo.ini 内置默认值）

struct PhotoConfig {
    var minWidth = 295
    var minHeight = 413
    var dstWidth = 295
    var dstHeight = 413
    var sMin = 0.05
    var sMax = 0.3
    var iMin = 0.1
    var iMax = 0.9
    var blueHMin = 2.5
    var blueHMax = 4.5
    var redHMin = 0.5
    var redHMax = 5.0
    var ratioXMin = 0.0
    var ratioXMax = 0.5
    var ratioYMin = 0.0
    var ratioYMax = 0.5
    var faceMinRatio = 0.32
    var widthFactor = 1.6181229773462784
    var jpegQuality = 0.4
    var marker = Data([0xFF, 0x02, 0x00, 0x08, 0x67, 0x6A, 0x67, 0x77, 0x79, 0x32]) // "gjgwy2"
}

// MARK: - 错误（与原程序中文提示一致）

enum ProcessError: LocalizedError {
    case loadFailed
    case notJPEG
    case tooSmall
    case noFace
    case background
    case ratio

    var errorDescription: String? {
        switch self {
        case .loadFailed: return "无法读取该图片文件。"
        case .notJPEG: return "打开照片文件类型不是JPG/JPEG格式，请选择JPG/JPEG格式照片文件。"
        case .tooSmall: return "打开照片文件像素数低。请选择高于或符合像素数要求的照片文件。"
        case .noFace: return "打开照片文件不符合要求。请选择正面人像标准证件照片文件。"
        case .background: return "打开照片文件背景不符合要求。请选择白色或蓝色背景照片文件。"
        case .ratio: return "打开照片文件人像头部比例不符合要求。请选择头部比例适当的照片文件。"
        }
    }
}

// MARK: - 结果

struct ProcessedPhoto {
    let original: CGImage
    let output: CGImage          // 295 × 413
    let faceBox: CGRect          // 原图像素坐标（左上原点）
    let cropBox: CGRect
}

// MARK: - 处理器

enum PhotoProcessor {
    static var config = PhotoConfig()

    // 加载并应用 EXIF 方向，返回像素级 CGImage
    static func loadImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 8000
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func isJPEG(_ url: URL) -> Bool {
        guard let h = FileHandle(forReadingAtPath: url.path) else { return false }
        defer { try? h.close() }
        let d = h.readData(ofLength: 2)
        return d == Data([0xFF, 0xD8])
    }

    // MARK: 人脸检测（Apple Vision，替代原 OpenCV Haar）

    static func largestFace(in image: CGImage) -> CGRect? {
        let maxDim = 1600
        let detImg = image.width > maxDim || image.height > maxDim ? downscaled(image, maxDimension: maxDim) ?? image : image
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: detImg, orientation: .up)
        try? handler.perform([request])
        guard let obs = request.results, !obs.isEmpty else { return nil }
        var best = obs[0]
        var bestW = best.boundingBox.width
        for o in obs.dropFirst() where o.boundingBox.width > bestW {
            best = o; bestW = o.boundingBox.width
        }
        // Vision 归一化框，原点在左下 → 转原图像素（左上原点）
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let x = best.boundingBox.minX * w
        let y = (1 - best.boundingBox.maxY) * h
        let fw = best.boundingBox.width * w
        let fh = best.boundingBox.height * h
        return CGRect(x: x, y: y, width: fw, height: fh)
    }

    // MARK: 背景色检查（3 个 3×3 采样点 → RGB→HSV）

    private enum BGClass { case white, blue, red, other }

    static func backgroundOK(_ image: CGImage) -> Bool {
        let img = (image.width > 800 || image.height > 800) ? downscaled(image, maxDimension: 800) ?? image : image
        guard let bmp = bitmap(img) else { return true }
        let W = CGFloat(bmp.width), H = CGFloat(bmp.height)
        let points: [(CGFloat, CGFloat)] = [(0.10, 0.10), (0.10, 0.25), (0.90, 0.167)]
        var first: BGClass? = nil
        for (fx, fy) in points {
            let cx = Int(fx * W), cy = Int(fy * H)
            let (r, g, b) = meanRGB(bmp, cx: cx, cy: cy)
            let hsv = toHSV(r: r, g: g, b: b)
            let cls = classify(hsv.h, hsv.s, hsv.v)
            if cls == .other { return false }
            if let f = first { if f != cls { return false } } else { first = cls }
        }
        return true
    }

    private static func classify(_ h: Double, _ s: Double, _ v: Double) -> BGClass {
        if s <= config.sMax && v >= config.iMin { return .white }
        if h >= config.blueHMin && h <= config.blueHMax && s >= config.sMin { return .blue }
        if h >= config.redHMin && h <= config.redHMax && s >= config.sMin { return .red }
        return .other
    }

    private static func toHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let r = r / 255, g = g / 255, b = b / 255
        let mx = max(r, g, b), mn = min(r, g, b), delta = mx - mn
        let v = mx
        let s = mx == 0 ? 0 : delta / mx
        var h = 0.0
        if delta != 0 {
            if mx == r { h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = 60 * ((b - r) / delta + 2) }
            else { h = 60 * ((r - g) / delta + 4) }
            if h < 0 { h += 360 }
        }
        return (h * .pi / 180, s, v)
    }

    // MARK: 主流程

    static func process(url: URL) -> Result<ProcessedPhoto, ProcessError> {
        guard isJPEG(url) else { return .failure(.notJPEG) }
        guard let img = loadImage(from: url) else { return .failure(.loadFailed) }
        let W = img.width, H = img.height
        guard W >= config.minWidth, H >= config.minHeight else { return .failure(.tooSmall) }
        guard let face = largestFace(in: img) else { return .failure(.noFace) }

        let faceRatio = Double(face.width) / Double(W)
        guard faceRatio >= config.faceMinRatio else { return .failure(.noFace) }

        guard backgroundOK(img) else { return .failure(.background) }

        // 扩框（忠实复刻：宽 = trunc(脸宽 × 1.618)；高 = round(宽 × 413/295)）
        var cropW = Int(Double(face.width) * config.widthFactor)
        var cropH = Int(Double(cropW) * Double(config.dstHeight) / Double(config.dstWidth) + 0.5)

        // 与原程序一致：裁剪框不得超过图像边界（cropW > 图宽 → cropW = 图宽，x = 0）
        if cropW > W { cropW = W }
        if cropH > H { cropH = H }

        var cx = Int(face.midX) - cropW / 2
        var cy = Int(face.midY) - cropH / 2
        cx = min(max(cx, 0), W - cropW)
        cy = min(max(cy, 0), H - cropH)
        let crop = CGRect(x: cx, y: cy, width: cropW, height: cropH)

        // 留白比例校验
        let left = Double(face.minX - crop.minX) / Double(cropW)
        let right = Double(crop.maxX - face.maxX) / Double(cropW)
        let top = Double(face.minY - crop.minY) / Double(cropH)
        let okX = left >= config.ratioXMin && left <= config.ratioXMax &&
                  right >= config.ratioXMin && right <= config.ratioXMax
        let okY = top >= config.ratioYMin && top <= config.ratioYMax
        guard okX && okY else { return .failure(.ratio) }

        guard let out = cropAndResize(img, crop: crop, to: CGSize(width: config.dstWidth, height: config.dstHeight)) else {
            return .failure(.loadFailed)
        }
        return .success(ProcessedPhoto(original: img, output: out, faceBox: face, cropBox: crop))
    }

    // MARK: 保存（质量 40 → 追加 10 字节标记）

    static func save(_ output: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ProcessError.loadFailed
        }
        let props = [kCGImageDestinationLossyCompressionQuality: config.jpegQuality] as CFDictionary
        CGImageDestinationAddImage(dest, output, props)
        guard CGImageDestinationFinalize(dest) else { throw ProcessError.loadFailed }
        if let fh = FileHandle(forWritingAtPath: url.path) {
            fh.seekToEndOfFile()
            fh.write(config.marker)
            try fh.close()
        }
    }

    // MARK: - 位图 / 缩放辅助

    private static func bitmap(_ image: CGImage) -> (data: [UInt8], width: Int, height: Int)? {
        let w = image.width, h = image.height, bpr = w * 4
        var data = [UInt8](repeating: 0, count: h * bpr)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bpr, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    private static func meanRGB(_ bmp: (data: [UInt8], width: Int, height: Int), cx: Int, cy: Int) -> (Double, Double, Double) {
        var r = 0.0, g = 0.0, b = 0.0, n = 0.0
        for yy in max(0, cy - 1)...min(bmp.height - 1, cy + 1) {
            for xx in max(0, cx - 1)...min(bmp.width - 1, cx + 1) {
                let o = yy * bmp.width * 4 + xx * 4
                r += Double(bmp.data[o]); g += Double(bmp.data[o + 1]); b += Double(bmp.data[o + 2]); n += 1
            }
        }
        return (r / n, g / n, b / n)
    }

    private static func downscaled(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let scale = min(1.0, CGFloat(maxDimension) / CGFloat(max(image.width, image.height)))
        if scale >= 1.0 { return image }
        let w = Int(CGFloat(image.width) * scale), h = Int(CGFloat(image.height) * scale)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    private static func cropAndResize(_ image: CGImage, crop: CGRect, to: CGSize) -> CGImage? {
        guard let cropped = image.cropping(to: crop) else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: Int(to.width), height: Int(to.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(origin: .zero, size: to))
        return ctx.makeImage()
    }
}
