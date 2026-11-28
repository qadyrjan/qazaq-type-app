import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-icon <app-icon-path> <menu-icon-path>\n", stderr)
    exit(EXIT_FAILURE)
}

let logoText = "QT" as NSString

/// Draws `text` centred on its cap height inside `rect`.
func drawCentered(
    _ text: NSString,
    in rect: NSRect,
    font: NSFont,
    color: NSColor
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: font.pointSize * -0.02,
    ]
    let width = text.size(withAttributes: attributes).width
    // `draw(at:)` takes the bottom of the line box, which lies one
    // descender below the baseline.
    let baseline = rect.midY - font.capHeight / 2
    text.draw(
        at: NSPoint(x: rect.midX - width / 2, y: baseline + font.descender),
        withAttributes: attributes
    )
}

func writeTIFF(_ image: NSImage, to path: String, name: String) {
    guard let data = image.tiffRepresentation else {
        fputs("failed to render \(name)\n", stderr)
        exit(EXIT_FAILURE)
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
    } catch {
        fputs("failed to write \(name): \(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

// Application icon: white "QT" on a teal rounded square.
let size = NSSize(width: 512, height: 512)
let image = NSImage(size: size)
image.lockFocus()
let tile = NSRect(origin: .zero, size: size).insetBy(dx: 40, dy: 40)
NSGradient(
    starting: NSColor(calibratedRed: 0.10, green: 0.56, blue: 0.52, alpha: 1),
    ending: NSColor(calibratedRed: 0.03, green: 0.38, blue: 0.36, alpha: 1)
)?.draw(
    in: NSBezierPath(roundedRect: tile, xRadius: 96, yRadius: 96),
    angle: -90
)
drawCentered(
    logoText,
    in: tile,
    font: NSFont.systemFont(ofSize: 220, weight: .heavy),
    color: .white
)
image.unlockFocus()
writeTIFF(image, to: CommandLine.arguments[1], name: "app icon")

// Menu bar icon: a template badge with the letters cut out, like the system
// "ABC" badge. macOS tints it for light and dark menu bars.
//
// Input source icons are 16x16 points, like Apple's own. A larger canvas is
// scaled down by macOS, which made the badge small and off-centre. Both the
// 1x and 2x bitmaps are drawn at their own pixel size so the edges stay sharp.
let menuPoints = NSSize(width: 16, height: 16)

func menuBitmap(scale: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(menuPoints.width * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fputs("failed to create the menu icon bitmap\n", stderr)
        exit(EXIT_FAILURE)
    }
    rep.size = menuPoints
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)

    let badge = NSRect(x: 0.5, y: 2, width: 15, height: 12)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: badge, xRadius: 2.5, yRadius: 2.5).fill()
    context.compositingOperation = .destinationOut
    drawCentered(
        logoText,
        in: badge,
        font: NSFont.systemFont(ofSize: 8.5, weight: .heavy),
        color: .black
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let menuImage = NSImage(size: menuPoints)
menuImage.addRepresentation(menuBitmap(scale: 1))
menuImage.addRepresentation(menuBitmap(scale: 2))
menuImage.isTemplate = true
writeTIFF(menuImage, to: CommandLine.arguments[2], name: "menu icon")
