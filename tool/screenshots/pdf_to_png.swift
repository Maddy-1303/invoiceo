// Draws the first page of a PDF into a PNG of the given width, on white,
// with macOS PDFKit (sharp at any size). Used for the website's sample
// documents made by sample_documents_test.dart:
//   swift tool/screenshots/pdf_to_png.swift in.pdf out.png 1240
import AppKit
import PDFKit

let args = CommandLine.arguments
guard args.count == 4,
      let doc = PDFDocument(url: URL(fileURLWithPath: args[1])),
      let page = doc.page(at: 0),
      let width = Double(args[3]) else {
  FileHandle.standardError.write("usage: pdf_to_png.swift in.pdf out.png width\n".data(using: .utf8)!)
  exit(1)
}

let box = page.bounds(for: .mediaBox)
let scale = CGFloat(width) / box.width
let pixelsWide = Int((box.width * scale).rounded())
let pixelsHigh = Int((box.height * scale).rounded())
guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let cg = context.cgContext
cg.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
cg.fill(CGRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
cg.interpolationQuality = .high
cg.scaleBy(x: scale, y: scale)
page.draw(with: .mediaBox, to: cg)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))
print("saved \(args[2]) (\(pixelsWide)×\(pixelsHigh))")
