---
date: 2026-11-21
status: proposed
---

# Use system controls for journal actions

## Context

The deadline list reserves a second bar for adding an item, and choosing a saved employer opens a separate screen for a short list.
Both controls occupy space needed for the selected record on an unfolded iPhone Duo.

## Decision

Place journal actions in SwiftUI navigation toolbars and use an anchored menu for suggestions.
Present records in native grouped lists alongside the selected detail when space permits.
Standard controls adopt the platform's appearance and accessibility settings as described in Apple's [Liquid Glass guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

## Alternatives

A full-width add button gives the action a persistent text label and reduces the space available for records at every text size.
A separate selection screen can accommodate search when an employer directory grows.

## Consequences

The system determines control size, material, and placement on each OS version.
Revisit employer selection if a searchable directory becomes necessary.

## Confirmation

Exercise the toolbar actions, change an employer without leaving the editor, and capture both columns on iPad and the unfolded iPhone Duo.
