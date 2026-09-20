import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: DMGBackground.swift <output.png> <metadata>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let metadata = CommandLine.arguments[2]
let canvasSize = NSSize(width: 1000, height: 650)

func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 2
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    (text as NSString).draw(in: rect, withAttributes: attributes)
}

func drawArrow(from start: NSPoint, to end: NSPoint) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = 4
    NSColor(calibratedWhite: 0.42, alpha: 1).setStroke()
    path.stroke()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: end)
    arrowHead.line(to: NSPoint(x: end.x - 18, y: end.y + 12))
    arrowHead.line(to: NSPoint(x: end.x - 18, y: end.y - 12))
    arrowHead.close()
    NSColor(calibratedWhite: 0.42, alpha: 1).setFill()
    arrowHead.fill()
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bitmapFormat: [],
    bytesPerRow: 0,
    bitsPerPixel: 0
), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Could not create bitmap graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
defer { NSGraphicsContext.restoreGraphicsState() }

NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

let contentRect = NSRect(x: 38, y: 32, width: 924, height: 586)
let panel = NSBezierPath(roundedRect: contentRect, xRadius: 22, yRadius: 22)
NSColor.white.setFill()
panel.fill()
NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
panel.lineWidth = 1
panel.stroke()

drawText(
    "安装 KeepAwake",
    in: NSRect(x: 70, y: 550, width: 860, height: 38),
    font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    color: NSColor(calibratedWhite: 0.12, alpha: 1),
    alignment: .center
)
drawText(
    "Install KeepAwake",
    in: NSRect(x: 70, y: 520, width: 860, height: 24),
    font: NSFont.systemFont(ofSize: 15, weight: .regular),
    color: NSColor(calibratedWhite: 0.42, alpha: 1),
    alignment: .center
)

drawArrow(from: NSPoint(x: 385, y: 365), to: NSPoint(x: 615, y: 365))
drawText(
    "拖拽到这里",
    in: NSRect(x: 375, y: 390, width: 250, height: 25),
    font: NSFont.systemFont(ofSize: 14, weight: .medium),
    color: NSColor(calibratedWhite: 0.42, alpha: 1),
    alignment: .center
)

let instructionBox = NSBezierPath(roundedRect: NSRect(x: 72, y: 190, width: 856, height: 92), xRadius: 14, yRadius: 14)
NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
instructionBox.fill()
NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
instructionBox.lineWidth = 1
instructionBox.stroke()
drawText(
    "拖完后从应用程序打开  ·  After copying, open KeepAwake from Applications",
    in: NSRect(x: 94, y: 232, width: 812, height: 25),
    font: NSFont.systemFont(ofSize: 15, weight: .medium),
    color: NSColor(calibratedWhite: 0.16, alpha: 1),
    alignment: .center
)
drawText(
    "首次打开：本包使用 Developer ID 签名，尚未经过 Apple 公证。若被拦截，请在“应用程序”中右键 KeepAwake → 打开；必要时到“系统设置 → 隐私与安全性 → 仍要打开”。",
    in: NSRect(x: 108, y: 199, width: 784, height: 30),
    font: NSFont.systemFont(ofSize: 11, weight: .regular),
    color: NSColor(calibratedWhite: 0.42, alpha: 1),
    alignment: .center
)

drawText(
    metadata,
    in: NSRect(x: 86, y: 150, width: 828, height: 22),
    font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
    color: NSColor(calibratedWhite: 0.48, alpha: 1),
    alignment: .center
)
drawText(
    "把左侧 App 拖到 Applications",
    in: NSRect(x: 100, y: 86, width: 800, height: 28),
    font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    color: NSColor(calibratedWhite: 0.10, alpha: 1),
    alignment: .center
)
drawText(
    "Drag the App to Applications to install",
    in: NSRect(x: 100, y: 58, width: 800, height: 24),
    font: NSFont.systemFont(ofSize: 14, weight: .regular),
    color: NSColor(calibratedWhite: 0.42, alpha: 1),
    alignment: .center
)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode DMG background as PNG\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: outputURL)
} catch {
    fputs("Could not write DMG background: \(error)\n", stderr)
    exit(1)
}
