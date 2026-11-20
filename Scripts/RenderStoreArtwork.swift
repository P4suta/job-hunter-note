import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

struct PaperArtwork {
  let drawing: CGContext
  let black = CGColor(gray: 0, alpha: 1)
  let white = CGColor(gray: 1, alpha: 1)

  func line(_ points: [CGPoint], ink: CGColor, width: CGFloat) {
    drawing.beginPath()
    drawing.addLines(between: points)
    drawing.setStrokeColor(ink)
    drawing.setLineWidth(width)
    drawing.strokePath()
  }

  func sheet(_ rect: CGRect, radius: CGFloat, ink: CGColor, border: CGFloat = 3) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    drawing.addPath(path)
    drawing.setFillColor(ink)
    drawing.setStrokeColor(black)
    drawing.setLineWidth(border)
    drawing.drawPath(using: .fillStroke)
  }

  func text(
    _ string: String, at x: CGFloat, baseline y: CGFloat, size: CGFloat,
    weight: NSFont.Weight = .regular, ink: CGColor
  ) {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: NSColor(cgColor: ink)!,
    ]
    let text = CTLineCreateWithAttributedString(
      NSAttributedString(string: string, attributes: attributes))
    drawing.saveGState()
    drawing.translateBy(x: x, y: y)
    drawing.scaleBy(x: 1, y: -1)
    drawing.textMatrix = .identity
    drawing.textPosition = .zero
    CTLineDraw(text, drawing)
    drawing.restoreGState()
  }

  func placed(x: CGFloat, y: CGFloat, angle: CGFloat, scale: CGFloat, _ draw: () -> Void) {
    drawing.saveGState()
    drawing.translateBy(x: x, y: y)
    drawing.rotate(by: angle * .pi / 180)
    drawing.scaleBy(x: scale, y: scale)
    draw()
    drawing.restoreGState()
  }

  func calendar() {
    for index in (0...3).reversed() {
      let offset = CGFloat(index) * 8
      sheet(CGRect(x: 0, y: offset, width: 580, height: 560), radius: 16, ink: white, border: 5)
    }
    drawing.setFillColor(black)
    drawing.fill(CGRect(x: 0, y: 12, width: 580, height: 98))
    text("12月", at: 35, baseline: 82, size: 48, weight: .bold, ink: white)
    text("金曜日", at: 431, baseline: 79, size: 32, weight: .semibold, ink: white)
    for x in stride(from: 74, through: 506, by: 72) {
      sheet(CGRect(x: x, y: -26, width: 15, height: 52), radius: 7, ink: white, border: 4)
    }
    text("04", at: 24, baseline: 436, size: 385, weight: .black, ink: black)
    line([CGPoint(x: 36, y: 470), CGPoint(x: 544, y: 470)], ink: black, width: 4)
    text("一次面接", at: 37, baseline: 532, size: 47, weight: .semibold, ink: black)
    text("14:00", at: 391, baseline: 531, size: 44, weight: .medium, ink: black)
  }

  func checklist(inverted: Bool = false) {
    let ink = inverted ? white : black
    let paper = inverted ? black : white
    for index in (0...2).reversed() {
      let d = CGFloat(index) * 10
      sheet(
        CGRect(x: d, y: d, width: 760, height: 880), radius: 7,
        ink: index == 0 ? paper : white, border: 4)
    }
    drawing.setFillColor(ink)
    drawing.fill(CGRect(x: 42, y: 70, width: 12, height: 68))
    text("応募記録", at: 78, baseline: 128, size: 72, weight: .heavy, ink: ink)
    line([CGPoint(x: 44, y: 172), CGPoint(x: 712, y: 172)], ink: ink, width: 7)
    for (index, title) in ["書類提出", "適性検査", "一次面接"].enumerated() {
      let y = 240 + CGFloat(index) * 133
      sheet(
        CGRect(x: 54, y: y - 26, width: 48, height: 48), radius: 7,
        ink: ink, border: 4)
      if index == 2 {
        drawing.setFillColor(paper)
        drawing.fill(CGRect(x: 59, y: y - 21, width: 38, height: 38))
      }
      if index < 2 {
        line(
          [CGPoint(x: 63, y: y - 2), CGPoint(x: 73, y: y + 9), CGPoint(x: 94, y: y - 13)],
          ink: paper, width: 6)
      }
      text(title, at: 135, baseline: y + 16, size: 57, weight: .semibold, ink: ink)
      line([CGPoint(x: 54, y: y + 65), CGPoint(x: 704, y: y + 65)], ink: ink, width: 2)
    }
    for y in [655, 738, 821] {
      line([CGPoint(x: 54, y: y), CGPoint(x: 704, y: y)], ink: ink, width: 2)
    }
  }

  func openPlanner() {
    for x in [0, 1190] {
      let page = CGRect(x: x, y: 0, width: 1190, height: 1580)
      sheet(page, radius: 32, ink: white, border: 10)
      for y in stride(from: 210, through: 1480, by: 105) {
        line([CGPoint(x: x + 72, y: y), CGPoint(x: x + 1110, y: y)], ink: black, width: 2)
      }
      line([CGPoint(x: x + 72, y: 132), CGPoint(x: x + 1110, y: 132)], ink: black, width: 6)
    }
    for y in stride(from: 105, through: 1500, by: 152) {
      sheet(CGRect(x: 1148, y: y, width: 82, height: 18), radius: 9, ink: black)
    }
  }

  func render(header: Bool) {
    let height = header ? 1646 : 2560
    drawing.translateBy(x: 0, y: CGFloat(height))
    drawing.scaleBy(x: 1, y: -1)
    drawing.setLineJoin(.round)
    drawing.setLineCap(.round)
    drawing.setFillColor(black)
    drawing.fill(CGRect(x: 0, y: 0, width: 3840, height: height))
    if header {
      placed(x: -470, y: 510, angle: -12, scale: 1.72, openPlanner)
      placed(x: 1940, y: 504, angle: 8, scale: 1.00) { checklist() }
      placed(x: 1206, y: 564, angle: -6, scale: 1.08, calendar)
    } else {
      placed(x: -872, y: 400, angle: -8, scale: 2.2, openPlanner)
      placed(x: 2270, y: 980, angle: 9, scale: 1.17, calendar)
      placed(x: 1010, y: 902, angle: -7, scale: 1.36) { checklist(inverted: true) }
    }
  }
}

let folder = URL(fileURLWithPath: "store/artwork/ja", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for (name, height) in [("product-page-header", 1646), ("search-results", 2560)] {
  let context = CGContext(
    data: nil, width: 3840, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  PaperArtwork(drawing: context).render(header: height == 1646)
  let output = CGImageDestinationCreateWithURL(
    folder.appending(path: name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(output, context.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(output))
}
