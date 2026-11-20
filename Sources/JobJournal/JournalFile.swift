import Foundation

public struct JournalFile: Sendable {
  public let url: URL
  public init(url: URL) { self.url = url }

  public func load() throws -> Journal {
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return Journal()
    }
    return try JSONDecoder().decode(Journal.self, from: data)
  }

  public func write(_ journal: Journal) throws {
    try journal.validate()
    let data = try JSONEncoder().encode(journal)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(
      to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
}
