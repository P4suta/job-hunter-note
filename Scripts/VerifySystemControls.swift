import Foundation

let restrictions = [
  (
    #"\.(toolbarBackground|presentationBackground|glassEffect|preferredColorScheme)\s*\("#,
    [
      ".toolbarBackground(.white)", ".presentationBackground(.clear)", ".glassEffect()",
      ".preferredColorScheme(.dark)",
    ]
  ),
  (
    #"\.(lineLimit|minimumScaleFactor)\s*\(|\.system\s*\(\s*size\s*:"#,
    [".lineLimit(1)", ".minimumScaleFactor(0.5)", ".system(size: 15)"]
  ),
  (#"\.foregroundStyle\(\s*\.(secondary|tertiary|quaternary)\b"#, [".foregroundStyle(.secondary)"]),
  (
    #"Color\s*\(\s*(red|hue|white)\s*:|\b(Color|UIColor)\.(white|black|red|blue|green|gray)\b"#,
    ["Color(red: 1, green: 0, blue: 0)", "Color.blue", "UIColor.gray"]
  ),
  (#"UIDesignRequiresCompatibility"#, ["<key>UIDesignRequiresCompatibility</key>"]),
]
let root = URL(fileURLWithPath: "App", isDirectory: true)
let files =
  (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
  .compactMap { $0 as? URL }).filter { ["swift", "plist"].contains($0.pathExtension) }
let sources = try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
let valid = #"Text("用件").font(.title).foregroundStyle(Color(uiColor: .label))"#
var failures: [String] = []
for (pattern, examples) in restrictions {
  let regex = try NSRegularExpression(pattern: pattern)
  func matches(_ source: String) -> Bool {
    regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) != nil
  }
  guard examples.allSatisfy(matches), !matches(valid) else {
    fatalError("System control check does not recognize its fixtures: \(pattern)")
  }
  for (file, source) in sources where matches(source) { failures.append("\(file): \(pattern)") }
}
if !failures.isEmpty {
  FileHandle.standardError.write(Data((failures.joined(separator: "\n") + "\n").utf8))
  exit(EXIT_FAILURE)
}
print("Verified system control styling and its rejecting fixtures.")
