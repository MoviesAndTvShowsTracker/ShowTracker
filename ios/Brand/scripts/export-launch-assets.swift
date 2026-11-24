// Exports the App Store icon and the launch-screen mark from the smoke artwork.
//
//   swift ios/Brand/scripts/export-launch-assets.swift          # export
//   swift ios/Brand/scripts/export-launch-assets.swift --check  # verify outputs
//
// Source: ios/Brand/AppIcon-1024.png (painted art with a baked rounded tile + white margin).
// Outputs:
//   AppIcon.appiconset/AppIcon.png       1024², opaque, full-bleed (iOS applies the mask)
//   LaunchMark.imageset/LaunchMark@2x/@3x 256² / 384², transparent continuous-corner tile

import AppKit
import ImageIO

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("Marquee/Resources/Assets.xcassets")
let iconURL = assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png")
let markDir = assets.appendingPathComponent("LaunchMark.imageset")
let sourceURL = root.appendingPathComponent("Brand/AppIcon-1024.png")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("FAIL: \(message)\n".data(using: .utf8)!)
    exit(1)
}

func bitmap(_ url: URL) -> NSBitmapImageRep {
    guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else {
        fail("cannot read \(url.lastPathComponent)")
    }
    return rep
}

func check() {
    let icon = bitmap(iconURL)
    guard icon.pixelsWide == 1024, icon.pixelsHigh == 1024 else { fail("AppIcon is not 1024×1024") }
    guard !icon.hasAlpha else { fail("AppIcon has alpha") }
    let corner = icon.colorAt(x: 2, y: 2)!.usingColorSpace(.sRGB)!
    guard corner.redComponent + corner.greenComponent + corner.blueComponent < 2.9 else {
        fail("AppIcon corner is white (baked tile still present)")
    }
    // Real artwork, not a blank render: the four quarter-points mix light paper and dark smoke.
    let samples = [(256, 256), (768, 256), (256, 768), (768, 768), (512, 512)].map { x, y -> CGFloat in
        let c = icon.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
        return c.redComponent + c.greenComponent + c.blueComponent
    }
    guard samples.max()! > 2.0 else { fail("AppIcon has no light paper (blank or black render)") }
    guard samples.max()! - samples.min()! > 0.6 else { fail("AppIcon is flat (artwork missing)") }
    let mark = bitmap(markDir.appendingPathComponent("LaunchMark@3x.png"))
    guard mark.pixelsWide == 384, mark.pixelsHigh == 384 else { fail("LaunchMark@3x is not 384×384") }
    guard mark.colorAt(x: 1, y: 1)!.alphaComponent == 0 else { fail("LaunchMark corner is not transparent") }
    guard mark.colorAt(x: 192, y: 192)!.alphaComponent == 1 else { fail("LaunchMark center is not opaque") }
    print("OK: AppIcon full-bleed, LaunchMark @3x 384² with transparent corners")
}

/// The baked tile's bounds: first non-white pixel scanning in from each edge along the centre lines.
func tileRect(_ rep: NSBitmapImageRep) -> NSRect {
    let w = rep.pixelsWide, h = rep.pixelsHigh
    func isPaper(_ x: Int, _ y: Int) -> Bool {
        let c = rep.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
        return c.redComponent + c.greenComponent + c.blueComponent > 2.94
    }
    let left = (0..<w).first { !isPaper($0, h / 2) } ?? 0
    let right = (0..<w).reversed().first { !isPaper($0, h / 2) } ?? w - 1
    let top = (0..<h).first { !isPaper(w / 2, $0) } ?? 0
    let bottom = (0..<h).reversed().first { !isPaper(w / 2, $0) } ?? h - 1
    // Bitmap rows run top-down; NSImage drawing rects are bottom-up.
    return NSRect(x: left, y: h - 1 - bottom, width: right - left + 1, height: bottom - top + 1)
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(url.lastPathComponent)") }
}

/// Draws `art` (already cropped) into a size² canvas; opaque canvases carry no alpha channel.
func render(_ art: CGImage, size: Int, opaque: Bool, clipRadius: CGFloat? = nil) -> CGImage {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info
    )!
    ctx.interpolationQuality = .high
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    if let r = clipRadius {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.clip()
    }
    ctx.draw(art, in: rect)
    return ctx.makeImage()!
}

func export() {
    let source = bitmap(sourceURL)
    let tile = tileRect(source)
    // Step inside the baked tile far enough to lose its rounded corners.
    // CGImage cropping uses top-left origin; tileRect is bottom-up, so flip y.
    let inset = tile.insetBy(dx: tile.width * 0.07, dy: tile.height * 0.07)
    let cropTopLeft = CGRect(
        x: inset.minX, y: CGFloat(source.pixelsHigh) - inset.maxY,
        width: inset.width, height: inset.height
    ).integral
    guard let art = source.cgImage?.cropping(to: cropTopLeft) else { fail("cannot crop artwork") }

    writePNG(render(art, size: 1024, opaque: true), to: iconURL)

    try? FileManager.default.createDirectory(at: markDir, withIntermediateDirectories: true)
    for (scale, px) in [(2, 256), (3, 384)] {
        let mark = render(art, size: px, opaque: false, clipRadius: CGFloat(px) * 0.2237)
        writePNG(mark, to: markDir.appendingPathComponent("LaunchMark@\(scale)x.png"))
    }
    let contents = """
    {
      "images" : [
        { "idiom" : "universal", "scale" : "1x" },
        { "filename" : "LaunchMark@2x.png", "idiom" : "universal", "scale" : "2x" },
        { "filename" : "LaunchMark@3x.png", "idiom" : "universal", "scale" : "3x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
    try! contents.write(to: markDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("Exported AppIcon + LaunchMark (tile \(Int(tile.width))px, crop \(Int(inset.width))px)")
}

if CommandLine.arguments.contains("--check") {
    check()
    exit(0)
}
export()
check()
