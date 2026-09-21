---
title: promote the progress seam to a shared package
state: inbox
created: 2026-09-15
tags: [enhancement, spike]
subsystems: [console]
---

once `internal/progress` is built and proven in console, evaluate pulling the seam into a shared package (a `df/pb` sibling of `dl`/`dd`, or a console-exported module) so the archive suite's three copies can retire onto one: reef's `kernel.Progress` (which c8's `cmd/tui` and the job-attach wire adapter also consume), flo's local `ProgressReporter` with its own `progressModel`/`withProgress`/`isTTY`, and c8's `teaProgress`. The shared package would carry the `Progress` interface, `Op`/`Label`/`FileVerb` vocabulary, `NilProgress` + `wantsProgress`, the `LogProgress` throttled fallback, the TTY-selection `withProgress` runner, the snapshot-passing contract, and the pure `View(Snapshot) string` render function (lipgloss styling, no display runtime) — the render is shared, the transport is not. The live-render backend stays per-consumer (console's lean in-place writer vs the archive suite's bubbletea programs) — the seam is backend-agnostic on purpose, so the shared package must define the reporter contract without importing a display library.

## why

the seam is identical in shape across all three, drifted in the details (event vocabulary, throttling constants, the copied/`FileVerb` distinction exists only in reef), and each copy is a maintenance surface that renders the same events into a different sink. Consolidating is the reference's payoff: the practice gets one named, tested progress seam instead of three, and future long-running work in any repo consumes it. Sequencing: this is a follow-on, not part of the reference build — the archive suite consolidations land as their own retrofits after the suite re-adopts the console conventions, and the job-attach wire adapter is the one consumer with a host-side timing story (server-computed throughput/ETA) that the shared contract must accommodate, not overwrite.
