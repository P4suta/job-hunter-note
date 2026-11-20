---
date: 2026-11-20
status: proposed
---

# Preserve selection across window sizes

## Context

A job seeker can unfold an iPhone Duo or resize an iPad window while editing a deadline.
Apple recommends preserving the current task as the available space changes in its [iPhone Duo guidance](https://developer.apple.com/iphone-duo/prepare/).

## Decision

Keep the selection and form in the parent view in SwiftUI.
Use native tabs, sheets, and text styles with monochrome content inside a [navigation split view](https://developer.apple.com/documentation/swiftui/navigationsplitview).

## Alternatives

Separate layouts for each device could use different controls but would require transferring edits during each transition.

## Consequences

The system controls the column layout and toolbar positions.
Revisit the choice if a future workflow needs distinct controls on each side of the fold.

## Confirmation

Open a record and a form at different window sizes and verify that the selection and typed text survive.
