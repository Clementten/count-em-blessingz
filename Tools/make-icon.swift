// Renders the "overflowing honeypot" app icon (BLUEPRINT section 15) as three 1024x1024 PNGs without alpha.
// Usage: swift Tools/make-icon.swift <output-directory>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Palette {
    let ground, pot, rim, opening, coinFace, coinEdge, band, honey, lattice: UInt32
}

let light = Palette(ground: 0x0B3B2E, pot: 0xE0B83E, rim: 0xB98A1E, opening: 0x2A1B05, coinFace: 0xF2CE5B, coinEdge: 0xA8801C, band: 0xC8362C, honey: 0xFFB627, lattice: 0xD4AF37)
let dark = Palette(ground: 0x04170F, pot: 0xC9A23A, rim: 0x94701A, opening: 0x1C1203, coinFace: 0xE2BE55, coinEdge: 0x86650F, band: 0xA92D25, honey: 0xE39A1C, lattice: 0xD4AF37)
let tinted = Palette(ground: 0x0E0E0F, pot: 0xE8E8E8, rim: 0x9A9A9A, opening: 0x1A1A1A, coinFace: 0xF5F5F5, coinEdge: 0x7A7A7A, band: 0x8A8A8A, honey: 0xCFCFCF, lattice: 0xFFFFFF)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(_ p: Palette, to url: URL) {
    let size = 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("context") }
    ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)      // origin top-left
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)

    // Ground, glow, lattice
    ctx.setFillColor(color(p.ground)); ctx.fill(canvas)
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.12), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 430), startRadius: 0, endCenter: CGPoint(x: 512, y: 430), endRadius: 560, options: [])
    ctx.saveGState()
    ctx.setStrokeColor(color(p.lattice, 0.11)); ctx.setLineWidth(3)
    var offset: CGFloat = -1024
    while offset <= 1024 {
        ctx.move(to: CGPoint(x: offset, y: 0)); ctx.addLine(to: CGPoint(x: offset + 1024, y: 1024))
        ctx.move(to: CGPoint(x: offset, y: 1024)); ctx.addLine(to: CGPoint(x: offset + 1024, y: 0))
        offset += 160
    }
    ctx.strokePath(); ctx.restoreGState()

    // Everything below is the artwork. Its bounding box is x 172...868, y 298...894, so shift it to centre
    // that box on the 1024 canvas (the ground, glow and lattice above stay put).
    ctx.saveGState()
    ctx.translateBy(x: 512 - (172 + 868) / 2, y: 512 - (298 + 894) / 2)

    // Shadow and two flat coins at the base
    ctx.setFillColor(color(0x000000, 0.28)); ctx.fillEllipse(in: CGRect(x: 262, y: 826, width: 500, height: 60))
    func flatCoin(_ cx: CGFloat, _ cy: CGFloat) {
        ctx.setFillColor(color(p.coinEdge)); ctx.fillEllipse(in: CGRect(x: cx - 78, y: cy - 16, width: 156, height: 44))
        ctx.setFillColor(color(p.coinFace)); ctx.fillEllipse(in: CGRect(x: cx - 78, y: cy - 26, width: 156, height: 44))
        ctx.setStrokeColor(color(p.coinEdge)); ctx.setLineWidth(6); ctx.strokeEllipse(in: CGRect(x: cx - 78, y: cy - 26, width: 156, height: 44))
    }
    flatCoin(250, 862); flatCoin(790, 866)

    // Pot body
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 337, y: 500)); body.addLine(to: CGPoint(x: 687, y: 500))
    body.addCurve(to: CGPoint(x: 700, y: 760), control1: CGPoint(x: 745, y: 560), control2: CGPoint(x: 760, y: 680))
    body.addCurve(to: CGPoint(x: 512, y: 828), control1: CGPoint(x: 660, y: 815), control2: CGPoint(x: 580, y: 828))
    body.addCurve(to: CGPoint(x: 324, y: 760), control1: CGPoint(x: 444, y: 828), control2: CGPoint(x: 364, y: 815))
    body.addCurve(to: CGPoint(x: 337, y: 500), control1: CGPoint(x: 264, y: 680), control2: CGPoint(x: 279, y: 560))
    body.closeSubpath()
    ctx.setFillColor(color(p.pot)); ctx.addPath(body); ctx.fillPath()
    ctx.saveGState(); ctx.addPath(body); ctx.clip()
    ctx.setFillColor(color(0xFFFFFF, 0.22)); ctx.fillEllipse(in: CGRect(x: 300, y: 560, width: 150, height: 210))      // flat highlight
    ctx.setFillColor(color(0x000000, 0.18)); ctx.fill(CGRect(x: 250, y: 770, width: 540, height: 80))                // flat shade
    ctx.restoreGState()

    // Rim and opening
    ctx.setFillColor(color(p.rim)); ctx.fillEllipse(in: CGRect(x: 322, y: 454, width: 380, height: 92))
    ctx.setFillColor(color(p.opening)); ctx.fillEllipse(in: CGRect(x: 347, y: 470, width: 330, height: 64))

    // Coins rising from the opening (clipped at the rim's centre line so they sink into the pot)
    func coin(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        ctx.setFillColor(color(p.coinFace)); ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        ctx.setStrokeColor(color(p.coinEdge)); ctx.setLineWidth(7)
        ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        let ring = r * 46 / 64
        ctx.setStrokeColor(color(p.coinEdge, 0.7)); ctx.setLineWidth(5)
        ctx.strokeEllipse(in: CGRect(x: cx - ring, y: cy - ring, width: 2 * ring, height: 2 * ring))
        let hole = CGRect(x: cx - 15, y: cy - 15, width: 30, height: 30)
        ctx.setFillColor(color(p.ground)); ctx.addPath(CGPath(roundedRect: hole, cornerWidth: 3, cornerHeight: 3, transform: nil)); ctx.fillPath()
    }
    ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: 1024, height: 504))
    coin(420, 462, 64); coin(612, 448, 64); coin(516, 372, 70)
    ctx.restoreGState()

    // Front lip of the rim over the coins: lower half of an ellipse, stroked with uniform width
    let lip = CGMutablePath()
    lip.addArc(center: .zero, radius: 1, startAngle: 0, endAngle: .pi, clockwise: false,
               transform: CGAffineTransform(translationX: 512, y: 500).scaledBy(x: 178, y: 40))
    ctx.setStrokeColor(color(p.rim)); ctx.setLineWidth(26); ctx.setLineCap(.round)
    ctx.addPath(lip); ctx.strokePath()

    // Red band around the neck
    let band = CGRect(x: 292, y: 566, width: 440, height: 38)
    ctx.setFillColor(color(p.band)); ctx.addPath(CGPath(roundedRect: band, cornerWidth: 19, cornerHeight: 19, transform: nil)); ctx.fillPath()

    // Honey drip down the left side: wide where it leaves the rim, tapering to a bulb
    ctx.setFillColor(color(p.honey))
    let drip = CGMutablePath()
    drip.move(to: CGPoint(x: 322, y: 540)); drip.addLine(to: CGPoint(x: 398, y: 540))
    drip.addCurve(to: CGPoint(x: 374, y: 632), control1: CGPoint(x: 394, y: 576), control2: CGPoint(x: 376, y: 600))
    drip.addLine(to: CGPoint(x: 342, y: 632))
    drip.addCurve(to: CGPoint(x: 322, y: 540), control1: CGPoint(x: 344, y: 596), control2: CGPoint(x: 326, y: 568))
    drip.closeSubpath()
    ctx.addPath(drip); ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: 332, y: 616, width: 52, height: 56))
    ctx.fillEllipse(in: CGRect(x: 314, y: 526, width: 92, height: 28))      // rounded flare where honey leaves the rim
    ctx.restoreGState()

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("encode") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("write") }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
render(light, to: out.appendingPathComponent("icon-any.png"))
render(dark, to: out.appendingPathComponent("icon-dark.png"))
render(tinted, to: out.appendingPathComponent("icon-tinted.png"))
print("Wrote icons to \(out.path)")
