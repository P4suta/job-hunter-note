import Foundation

public enum Stage: String, Codable, CaseIterable, Sendable {
  case documents, assessment, interview, waiting
}

public enum JournalError: Error, Equatable {
  case missingName, missingTitle, invalidDay, invalidTime, missingRecord, alreadyCompleted,
    invalidFile
}

public struct Employer: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let name: String
  public fileprivate(set) var stage: Stage
}

public struct DeadlineDraft: Equatable, Sendable {
  public var company: String
  public var title: String
  public var day: Day
  public var time: Int?
  public var notify: Bool

  public init(company: String, title: String, day: Day, time: Int? = nil, notify: Bool = true) {
    self.company = company
    self.title = title
    self.day = day
    self.time = time
    self.notify = notify
  }
}

public struct Deadline: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let companyID: UUID
  public let title: String
  public let day: Day
  public let time: Int?
  public let notify: Bool
  public fileprivate(set) var completedAt: Date?

  func isDueBefore(_ other: Self) -> Bool {
    (day, time ?? 1440, title, id.uuidString)
      < (other.day, other.time ?? 1440, other.title, other.id.uuidString)
  }
}

public struct Journal: Codable, Equatable, Sendable {
  public private(set) var companies: [Employer] = []
  public private(set) var deadlines: [Deadline] = []
  public init() {}

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: CodingKeys.self)
    companies = try fields.decode([Employer].self, forKey: .companies)
    deadlines = try fields.decode([Deadline].self, forKey: .deadlines)
    try validate()
  }

  public func company(_ id: UUID) -> Employer? { companies.first { $0.id == id } }
  public func deadline(_ id: UUID) -> Deadline? { deadlines.first { $0.id == id } }

  @discardableResult
  public mutating func addEmployer(_ input: String, stage: Stage = .documents) throws -> UUID {
    let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw JournalError.missingName }
    if let company = companies.first(where: {
      $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == name
    }) {
      return company.id
    }
    let employer = Employer(id: UUID(), name: name, stage: stage)
    companies.append(employer)
    return employer.id
  }

  @discardableResult
  public mutating func save(_ draft: DeadlineDraft, editing id: UUID? = nil) throws -> UUID {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw JournalError.missingTitle }
    if let time = draft.time, !(0..<1440).contains(time) { throw JournalError.invalidTime }
    var index: Int?
    if let id {
      guard let found = deadlines.firstIndex(where: { $0.id == id }) else {
        throw JournalError.missingRecord
      }
      guard deadlines[found].completedAt == nil else { throw JournalError.alreadyCompleted }
      index = found
    }
    let companyID = try addEmployer(draft.company)
    let deadline = Deadline(
      id: id ?? UUID(), companyID: companyID, title: title, day: draft.day,
      time: draft.time, notify: draft.notify, completedAt: nil)
    if let index { deadlines[index] = deadline } else { deadlines.append(deadline) }
    return deadline.id
  }

  public mutating func complete(_ id: UUID, at date: Date) throws {
    guard let index = deadlines.firstIndex(where: { $0.id == id }) else {
      throw JournalError.missingRecord
    }
    if deadlines[index].completedAt == nil { deadlines[index].completedAt = date }
  }

  public mutating func setStage(_ stage: Stage, for id: UUID) throws {
    guard let index = companies.firstIndex(where: { $0.id == id }) else {
      throw JournalError.missingRecord
    }
    companies[index].stage = stage
  }

  public func open(on day: Day? = nil) -> [Deadline] {
    deadlines.filter { $0.completedAt == nil && (day == nil || day == $0.day) }
      .sorted { $0.isDueBefore($1) }
  }

  public func history(for company: UUID) -> [Deadline] {
    deadlines.filter { $0.companyID == company && $0.completedAt != nil }
      .sorted(using: [
        KeyPathComparator(\.completedAt, order: .reverse),
        KeyPathComparator(\.id, order: .reverse),
      ])
  }

  func validate() throws {
    let ids = Set(companies.map(\.id))
    let names = companies.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard ids.count == companies.count,
      Set(names).count == companies.count, !names.contains(""),
      Set(deadlines.map(\.id)).count == deadlines.count,
      deadlines.allSatisfy({
        ids.contains($0.companyID)
          && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && (0..<1440).contains($0.time ?? 0)
      })
    else { throw JournalError.invalidFile }
  }
}
