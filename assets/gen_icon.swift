import AppKit

func colorFromHex(_ hex: String) -> NSColor {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    let scanner = Scanner(string: s)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)
    return NSColor(
        calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1.0
    )
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: gen_icon <sfsymbol> <outputPNGpath> [colorHex1] [colorHex2]")
    exit(1)
}
let symbol = args[1]
let outPath = args[2]
let color1 = args.count > 3 ? colorFromHex(args[3]) : NSColor(calibratedRed: 0.30, green: 0.58, blue: 0.98, alpha: 1.0)
let color2 = args.count > 4 ? colorFromHex(args[4]) : NSColor(calibratedRed: 0.52, green: 0.30, blue: 0.92, alpha: 1.0)
let size: CGFloat = 1024

let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
guard let rawSymbol = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) else {
    print("symbol not found: \(symbol)")
    exit(1)
}
rawSymbol.isTemplate = true

let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)
let gradient = NSGradient(colors: [color1, color2])
gradient?.draw(in: path, angle: -50)

let symbolSize = rawSymbol.size
let symbolRect = NSRect(
    x: (size - symbolSize.width) / 2,
    y: (size - symbolSize.height) / 2,
    width: symbolSize.width,
    height: symbolSize.height
)

let tinted = NSImage(size: symbolSize)
tinted.lockFocus()
NSColor.white.withAlphaComponent(0.95).set()
NSRect(origin: .zero, size: symbolSize).fill()
rawSymbol.draw(
    in: NSRect(origin: .zero, size: symbolSize),
    from: .zero,
    operation: .destinationIn,
    fraction: 1.0
)
tinted.unlockFocus()

tinted.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("failed to render")
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
