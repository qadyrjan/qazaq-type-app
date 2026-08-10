import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-icon <app-icon-path> <menu-icon-path>\n", stderr)
    exit(EXIT_FAILURE)
}

let size = NSSize(width: 64, height: 64)
let image = NSImage(size: size)
image.lockFocus()

NSColor(
    calibratedRed: 15.0 / 255.0,
    green: 118.0 / 255.0,
    blue: 110.0 / 255.0,
    alpha: 1
).setFill()
NSBezierPath(
    roundedRect: NSRect(origin: .zero, size: size),
    xRadius: 14,
    yRadius: 14
).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 25, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
]
("KZ" as NSString).draw(
    in: NSRect(x: 0, y: 17, width: size.width, height: 32),
    withAttributes: attributes
)
image.unlockFocus()

guard let data = image.tiffRepresentation else {
    fputs("failed to render TIFF icon\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
} catch {
    fputs("failed to write TIFF icon: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}

let menuSize = NSSize(width: 32, height: 32)
let menuImage = NSImage(size: menuSize)
menuImage.lockFocus()
NSColor.black.setFill()
NSBezierPath(
    roundedRect: NSRect(x: 2, y: 5, width: 28, height: 22),
    xRadius: 4,
    yRadius: 4
).fill()

let menuParagraph = NSMutableParagraphStyle()
menuParagraph.alignment = .center
let menuAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: menuParagraph,
]
("KZ" as NSString).draw(
    in: NSRect(x: 2, y: 8, width: 28, height: 15),
    withAttributes: menuAttributes
)
menuImage.unlockFocus()

guard let menuData = menuImage.tiffRepresentation else {
    fputs("failed to render menu TIFF icon\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    try menuData.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
} catch {
    fputs("failed to write menu TIFF icon: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
