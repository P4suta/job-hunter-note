// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "JobJournal",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [.library(name: "JobJournal", targets: ["JobJournal"])],
  targets: [
    .target(name: "JobJournal"),
    .testTarget(name: "JobJournalTests", dependencies: ["JobJournal"]),
  ]
)
