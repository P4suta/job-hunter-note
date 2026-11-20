import UIKit
import XCTest

enum TextContrast {
  static func minimumOuterThirdContrast(in image: UIImage) throws -> Double {
    let glyphs = try XCTUnwrap(image.cgImage)
    let third = max(1, glyphs.height / 3)
    var minimum = Double.infinity
    for y in [0, glyphs.height - third] {
      let bounds = CGRect(x: 0, y: y, width: glyphs.width, height: third)
      let band = try XCTUnwrap(glyphs.cropping(to: bounds))
      minimum = min(minimum, try ratio(in: UIImage(cgImage: band)))
    }
    return minimum
  }

  static func ratio(in image: UIImage, centerOfControl: Bool = false) throws -> Double {
    let full = try XCTUnwrap(image.cgImage)
    let bounds = CGRect(x: 0, y: 0, width: full.width, height: full.height)
    let region: CGRect
    if centerOfControl {
      let width = min(bounds.width * 0.75, 100 * image.scale)
      let height = min(bounds.height * 0.6, 24 * image.scale)
      region = CGRect(
        x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    } else {
      region = bounds
    }
    let sample = try XCTUnwrap(full.cropping(to: region.integral))
    let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: sample.width, height: sample.height,
        bitsPerComponent: 8, bytesPerRow: sample.width * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue))
    context.draw(sample, in: CGRect(x: 0, y: 0, width: sample.width, height: sample.height))
    let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
    let linear = (0...255).map { value in
      let channel = Double(value) / 255
      return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
    var luminance: [Double] = []
    let count = sample.width * sample.height
    luminance.reserveCapacity(count)
    for pixel in 0..<count {
      let offset = pixel * 4
      let red = linear[Int(pixels[offset])]
      let green = linear[Int(pixels[offset + 1])]
      let blue = linear[Int(pixels[offset + 2])]
      luminance.append(0.2126 * red + 0.7152 * green + 0.0722 * blue)
    }
    luminance.sort()
    let margin = count / 100
    return (luminance[count - 1 - margin] + 0.05) / (luminance[margin] + 0.05)
  }
}
