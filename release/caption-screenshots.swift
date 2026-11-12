#!/usr/bin/env swift
// Adds a headline to each App Store screenshot, so the captioned set is reproducible.
//
//   swift release/caption-screenshots.swift
//
// Reads  release/screenshots/<look>/NN-name.png        (1320 x 2868 raw screens)
// Writes release/screenshots-captioned/<look>/NN-name.png            (1320 x 2868: App Store Connect's 6.9" slot)
//        release/screenshots-captioned-1206x2622/<look>/NN-name.png  (1206 x 2622: the 6.1" slot, which is the required one)
// Both are opaque, with the headline on top. Upload each set into the slot that matches its size; App Store Connect
// rejects a file whose pixel size does not belong to the tab you drop it on ("File dimensions are invalid").
//
// Layout: a 420 px band at the top in the look's own background colour with the headline in the look's
// text colour (the same pairs the theme tests hold to 4.5:1), and the whole screen below it, scaled to fit,
// with rounded corners and a thin outline. System font (SF Pro Rounded, bold). macOS only (AppKit).
// Plan and reasons: release/SUBMISSION_AUDIT.md section 5.

import AppKit
import ImageIO
import UniformTypeIdentifiers

let canvas = CGSize(width: 1320, height: 2868)
let bandHeight: CGFloat = 420
let bottomMargin: CGFloat = 40
let sideMargin: CGFloat = 90
let cornerRadius: CGFloat = 56

struct Look {
    let id: String
    let background: UInt32     // the look's `background` token (Theme/Themes.swift)
    let text: UInt32           // the look's `textPrimary` token
    let outline: UInt32        // the look's `accent` token
}

let looks = [
    Look(id: "jade", background: 0x0B3B2E, text: 0xF6EBCB, outline: 0xD4AF37),
    Look(id: "grand", background: 0xFFE9EE, text: 0x3D1D40, outline: 0xB3223B),
    Look(id: "quiet", background: 0x15171A, text: 0xEDE6D6, outline: 0xB08D57),
]

/// Display order = file order. Headlines are 6 words or fewer.
let shots: [(source: String, output: String, headline: String)] = [
    ("01-home", "01-home", "Every angpao, safely in one place"),
    ("02-insights", "02-insights", "See who has blessed you"),
    ("06-import-review", "03-import-review", "Merge family lists, no cloud"),
    ("03-hall-of-fame", "04-hall-of-fame", "Never forget to say thanks"),
    ("04-add-blessing", "05-add-blessing", "Add a blessing in seconds"),
    ("05-vibes", "06-vibes", "Pick the look you love"),
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func headlineFont(size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .bold)
    if let rounded = base.fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: rounded, size: size) { return font }
    return base
}

/// Largest font size (84 down to 60) at which the headline fits in two lines of the band.
func fittingText(_ headline: String, color: NSColor) -> (NSAttributedString, CGRect) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    let width = canvas.width - 2 * sideMargin
    var size: CGFloat = 84
    while true {
        let string = NSAttributedString(string: headline, attributes: [
            .font: headlineFont(size: size), .foregroundColor: color, .paragraphStyle: paragraph,
        ])
        let box = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading])
        let lines = (box.height / headlineFont(size: size).boundingRectForFont.height).rounded()
        if (lines <= 2 && box.height <= bandHeight - 80) || size <= 60 { return (string, box) }
        size -= 4
    }
}

func render(source: URL, headline: String, look: Look, to outputs: [(url: URL, size: CGSize)]) throws {
    guard let screen = NSImage(contentsOf: source) else { throw NSError(domain: "caption", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read \(source.path)"]) }
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0       // AppKit only draws into RGBA; flattened below
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "caption", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot create bitmap"])
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    color(look.background).setFill()
    NSRect(origin: .zero, size: canvas).fill()

    // The whole screen, scaled to fit below the band (AppKit's origin is the bottom-left corner).
    let availableHeight = canvas.height - bandHeight - bottomMargin
    let scale = availableHeight / screen.size.height
    let screenSize = CGSize(width: screen.size.width * scale, height: availableHeight)
    let screenRect = CGRect(x: (canvas.width - screenSize.width) / 2, y: bottomMargin, width: screenSize.width, height: screenSize.height)
    let shape = NSBezierPath(roundedRect: screenRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    screen.draw(in: screenRect, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    color(look.outline, alpha: 0.55).setStroke()
    shape.lineWidth = 4
    shape.stroke()

    // The headline, centred in the band.
    let (text, box) = fittingText(headline, color: color(look.text))
    let bandTop = canvas.height
    let textY = bandTop - (bandHeight + box.height) / 2
    text.draw(with: CGRect(x: sideMargin, y: textY, width: canvas.width - 2 * sideMargin, height: box.height),
              options: [.usesLineFragmentOrigin, .usesFontLeading])

    NSGraphicsContext.restoreGraphicsState()
    for output in outputs {
        try FileManager.default.createDirectory(at: output.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeOpaquePNG(bitmap, size: output.size, to: output.url)
    }
}

/// App Store screenshots must not have transparency: copy the picture into an RGB context with no alpha channel,
/// resampled to `size` (the same size, or the smaller slot's size).
func writeOpaquePNG(_ bitmap: NSBitmapImageRep, size: CGSize, to url: URL) throws {
    func fail(_ message: String) -> NSError { NSError(domain: "caption", code: 3, userInfo: [NSLocalizedDescriptionKey: message]) }
    guard let picture = bitmap.cgImage,
          let flat = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw fail("cannot flatten the picture") }
    flat.interpolationQuality = .high
    flat.draw(picture, in: CGRect(origin: .zero, size: size))
    guard let opaque = flat.makeImage(),
          let target = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw fail("cannot create PNG") }
    CGImageDestinationAddImage(target, opaque, nil)
    guard CGImageDestinationFinalize(target) else { throw fail("cannot write PNG") }
}

// release/ is the folder this script lives in.
let releaseFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
var count = 0
for look in looks {
    for shot in shots {
        let source = releaseFolder.appending(path: "screenshots/\(look.id)/\(shot.source).png")
        let outputs: [(url: URL, size: CGSize)] = [
            (releaseFolder.appending(path: "screenshots-captioned/\(look.id)/\(shot.output).png"), canvas),
            (releaseFolder.appending(path: "screenshots-captioned-1206x2622/\(look.id)/\(shot.output).png"), CGSize(width: 1206, height: 2622)),
        ]
        do {
            try render(source: source, headline: shot.headline, look: look, to: outputs)
            count += 1
        } catch {
            FileHandle.standardError.write(Data("\(look.id)/\(shot.source): \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
print("Wrote \(count) captioned screenshots in two sizes: release/screenshots-captioned/ (1320 x 2868) and release/screenshots-captioned-1206x2622/")
