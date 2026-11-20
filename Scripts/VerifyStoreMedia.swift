import CoreGraphics
import Foundation
import ImageIO

struct MediaError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

struct StoreImage {
  let name: String
  let image: CGImage

  init(_ path: String) throws {
    name = path
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      CGImageSourceGetType(source) as String? == "public.png",
      let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw MediaError("Cannot read \(path)") }
    image = decoded
    guard [.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo) else {
      throw MediaError("\(path) must be opaque RGB.")
    }
  }

  func checkSize(_ width: Int, _ height: Int) throws {
    guard image.width == width && image.height == height else {
      throw MediaError(
        "\(name) is \(image.width) × \(image.height), expected \(width) × \(height).")
    }
  }

  func hasBlackDisplayEdge() -> Bool {
    let width = image.width
    let height = image.height
    let middleX = (width / 10)..<(width - width / 10)
    let middleY = (height / 10)..<(height - height / 10)
    func hasBand(along length: Int, isDark: (Int) -> Bool) -> Bool {
      let depth = min(length, max(8, length / 10))
      for edge in [0..<depth, (length - depth)..<length] {
        var thickness = 0
        for line in edge {
          thickness = isDark(line) ? thickness + 1 : 0
          if thickness == 8 { return true }
        }
      }
      return false
    }
    var samples = [UInt8](repeating: 0, count: width * height)
    return samples.withUnsafeMutableBytes { bytes -> Bool in
      let context = CGContext(
        data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      let pixels = bytes.bindMemory(to: UInt8.self)
      let vertical = hasBand(along: width) { x in
        middleY.allSatisfy { y in pixels[y * width + x] < 20 }
      }
      return vertical
        || hasBand(along: height) { y in
          middleX.allSatisfy { x in pixels[y * width + x] < 20 }
        }
    }
  }

  func checkContent(_ groups: [(ClosedRange<CGFloat>, [String])], crop: CGRect? = nil) throws {
    let region: CGImage
    if let crop {
      guard let cropped = image.cropping(to: crop) else {
        throw MediaError("Invalid crop in \(name)")
      }
      region = cropped
    } else {
      guard !hasBlackDisplayEdge() else { throw MediaError("\(name): black display edge") }
      region = image
    }
    for (columns, phrases) in groups {
      let width = CGFloat(region.width)
      let rectangle = CGRect(
        x: columns.lowerBound * width, y: 0,
        width: (columns.upperBound - columns.lowerBound) * width,
        height: CGFloat(region.height))
      guard let column = region.cropping(to: rectangle.integral) else {
        throw MediaError("Invalid text region in \(name)")
      }
      var text = try recognizeHorizontalText(column)
      if !phrases.allSatisfy({ text.contains($0) }) {
        let reduced = CGContext(
          data: nil, width: max(1, column.width / 2), height: max(1, column.height / 2),
          bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
        reduced.interpolationQuality = .high
        reduced.draw(column, in: CGRect(x: 0, y: 0, width: reduced.width, height: reduced.height))
        text += "\n" + (try recognizeHorizontalText(reduced.makeImage()!))
      }
      let missing = phrases.filter { !text.contains($0) }
      if !missing.isEmpty {
        throw MediaError("\(name): missing upright \(missing) in \(columns); found \(text)")
      }
    }
  }

  private func recognizeHorizontalText(_ region: CGImage) throws -> String {
    let input = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".png")
    defer { try? FileManager.default.removeItem(at: input) }
    guard
      let destination = CGImageDestinationCreateWithURL(
        input as CFURL, "public.png" as CFString, 1, nil)
    else {
      throw MediaError("Cannot prepare text recognition in \(name)")
    }
    CGImageDestinationAddImage(destination, region, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw MediaError("Cannot export text region in \(name)")
    }
    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "tesseract", input.path, "stdout", "-l", "jpn", "--psm", "11", "--dpi", "300",
    ]
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw MediaError(
        "Japanese text recognition failed for \(name) with status \(process.terminationStatus).")
    }
    return String(decoding: data, as: UTF8.self).filter { !$0.isWhitespace }
  }
}

let anywhere: ClosedRange<CGFloat> = 0...1
let deadlineColumns: [(ClosedRange<CGFloat>, [String])] = [
  (0...0.30, ["適性検査"]), (0.22...1, ["一次面接", "締切日", "前夜の通知"]),
]
let employerColumns: [(ClosedRange<CGFloat>, [String])] = [
  (0...0.36, ["応募先", "汐見工房", "適性検査"]), (0.22...1, ["提出履歴", "履歴書の提出"]),
]

do {
  let args = Array(CommandLine.arguments.dropFirst())
  if args.count == 1, !args[0].hasPrefix("--") {
    try StoreImage(CommandLine.arguments[1]).checkContent(deadlineColumns)
  } else {
    guard args.isEmpty || (args.count == 2 && args[0] == "--screenshots-dir") else {
      throw MediaError("Usage: VerifyStoreMedia.swift [--screenshots-dir PATH | LANDSCAPE_PNG]")
    }
    let base = (args.last ?? "store/screenshots/ja") + "/"
    var expected = Set<String>()
    for (device, w, h, prefix) in [
      ("iphone", 1206, 2622, ""), ("iphone-large", 1320, 2868, ""),
      ("iphone-duo", 1398, 2034, "outer-"),
    ] {
      let listName = "\(device)/01-\(prefix)deadlines.png"
      expected.insert(listName)
      let list = try StoreImage(base + listName)
      try list.checkSize(w, h)
      try list.checkContent([(anywhere, ["締切", "一次面接", "適性検査"])])
      let order = device == "iphone-duo" ? "03" : "02"
      let detailName = "\(device)/\(order)-\(prefix)deadline-detail.png"
      expected.insert(detailName)
      let detail = try StoreImage(base + detailName)
      try detail.checkSize(w, h)
      try detail.checkContent([(anywhere, ["一次面接", "締切日", "前夜の通知"])])
    }
    for (path, w, h, phrases) in [
      ("ipad/01-employers.png", 2064, 2752, employerColumns),
      ("ipad/02-deadline-detail.png", 2752, 2064, deadlineColumns),
      ("iphone-duo/02-inner-employers.png", 2853, 2007, employerColumns),
    ] {
      expected.insert(path)
      let screen = try StoreImage(base + path)
      try screen.checkSize(w, h)
      try screen.checkContent(phrases)
    }
    let files = try FileManager.default.subpathsOfDirectory(atPath: base)
    let actual = Set(
      files.filter {
        ["png", "jpg", "jpeg"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
      })
    guard actual == expected else {
      throw MediaError(
        "Unexpected screenshot set: \(actual.symmetricDifference(expected).sorted())")
    }
    for (file, height, crop) in [
      ("product-page-header", 1646, CGRect(x: 1097, y: 493, width: 1646, height: 661)),
      ("search-results", 2560, CGRect(x: 836, y: 765, width: 2168, height: 1030)),
    ] {
      let artwork = try StoreImage("store/artwork/ja/" + file + ".png")
      try artwork.checkSize(3840, height)
      try artwork.checkContent([(anywhere, ["応募記録", "12月", "面接"])], crop: crop)
    }
    print("Verified nine upright screenshots and both creative placements.")
  }
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(EXIT_FAILURE)
}
