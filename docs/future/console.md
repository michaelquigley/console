# console — the shape of a good console

A miniature tunnel that exists to demonstrate, in running code, how a Go CLI console should behave: where diagnostics go, how tabular output renders, how a fatal error teaches the fix. The tunnel is the excuse; the console is the artifact. Every idiom below is the practice's standard, distilled from zrok's controller and CLI and corrected where zrok itself drifted.

## The three channels

A line of output belongs to exactly one of three channels, and each channel has its own tool. This separation is the load-bearing idea; everything else in this document is furniture.

**Diagnostics → stderr, through `dl`.** The operational story of what the program is doing — state transitions, errors, branchy internals under `--verbose`. `dl` is initialized once in `init()` with diagnostics routed to stderr:

```go
dl.Init(dl.DefaultOptions().
    SetTrimPrefix("github.com/michaelquigley/console/").
    SetOutput(os.Stderr))
```

The `SetOutput(os.Stderr)` is explicit against the `df` release the reference builds on today; when the companion df card `dl-defaults-its-output-to-stderr` lands it becomes redundant — bare `dl.Init(dl.DefaultOptions())` is correct end to end. Keep the call either way as a statement of intent: the reference names its own channel split rather than trusting the default.

The trim prefix is the module path plus a slash, always. That ends the practice's three-way split (some repos trimmed a git-host path they didn't use, some trimmed the github org, one trimmed correctly) and matches the rule zrok follows: trim what the binary actually imports.

A background subsystem gets its own channel, pre-configured in `init()` — zrok's `mappings` analog:

```go
dl.ConfigureChannel("routes", dl.DefaultOptions().
    SetTrimPrefix("github.com/michaelquigley/console/").
    SetOutput(os.Stderr))
```

The share command's route refresher logs through `dl.ChannelLog("routes")`; pretty mode renders the lane as `|routes|`.

**The `--verbose` flag works.** The root command's `PersistentPreRun` re-initializes `dl` at `slog.LevelDebug` when `--verbose` is set. This is zrok's standing bug — its verbose path re-inits at `LevelInfo` and only the legacy logrus stack flips to debug, so `--verbose` is a no-op for most of its output. The reference does the obvious thing right:

```go
if verbose {
    dl.Init(dl.DefaultOptions().
        SetTrimPrefix("github.com/michaelquigley/console/").
        SetOutput(os.Stderr).
        SetLevel(slog.LevelDebug))
}
```

**Results → stdout.** The thing the user asked for — lists, endpoints, generated config — renders to stdout and never touches the logger. One deliberate exception, footnoted in the code: when a long-running command's only surface is its log (the `--headless` share mode, no TUI), the log *is* the UI, and results like the share endpoints are announced through `dl.Infof`. The program is the pipe; the log is its console.

**Fatal user errors → the `consoleui` idiom, stderr, exit 1.** A small local package — zrok's `tui` analog, with a house name:

```go
var SeriousBusiness = lipgloss.NewStyle().Foreground(lipgloss.Color("#D90166"))
var ErrorLabel = SeriousBusiness.Render("ERROR")
var Attention = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFA500"))
var WarningLabel = Attention.Render("WARNING")
var Code = lipgloss.NewStyle().Foreground(lipgloss.Color("#00FFFF"))

func Error(msg string, err error)
func Warning(msg string, v ...any)
```

`Error` renders `[ERROR]: <msg> (<err>)` to stderr and exits 1. The message is a sentence; the remedy is a rendered command, which is how the console teaches the fix:

```go
consoleui.Warning("your environment is out of date; use %v to update",
    consoleui.Code.Render("console update"))
```

No `panic(err)` in command paths. `--panic` exists as the operator's debug escape: with it set, `main` panics on a root-command error instead of rendering `consoleui.Error`.

## Message shape

The level discipline, in the shape zrok's controller demonstrates:

- `dl.Error` / `dl.Errorf` — this operation failed. Log it *and* return the error; the line carries the context, the value carries the failure.
- `dl.Info` / `dl.Infof` — a state transition happened: "created", "granted", "deleted", "accessing".
- `dl.Warn` / `dl.Warnf` — non-fatal anomaly or skip: "skipping influx client; no configuration".
- `dl.Debug` / `dl.Debugf` — branchy internals, visible under `--verbose` only.

The message names the operation, quotes its subjects, and ends errors with a `: %v` tail:

```go
dl.Errorf("error finding environment '%v' for '%v': %v", envZId, email, err)
dl.Infof("granted '%v' access to frontend '%v'", email, token)
dl.Infof("access the console share at the following endpoint: %v", endpoint)
```

At startup, long-running commands dump the effective configuration through `dl.Info(dd.MustInspect(cfg))` — a zrok idiom carried over; the operator sees exactly what the process resolved.

## The live console

`console share <target>` is the center of gravity: it is the one command that produces every surface in this document at once.

- Opens a small HTTP frontend on `127.0.0.1` (standing in for a zrok frontend) and proxies requests to `<target>`.
- **Live mode (default):** a lean scrollback console on one in-place writer (the mechanism, below) — colored like zrok's panes: dim timestamps, amber addresses, colored methods.
- **`--headless`:** no scrollback. Endpoints announced once through `dl.Infof` (the log-is-UI exception above); each request streams as `dl.Infof("%v -> %v %v", remoteAddr, method, path)`.
- **Route refresher:** a background loop that re-reads the share record and refreshes route state, logging through `dl.ChannelLog("routes")`. Its dump is a Debug line — invisible by default, visible under `--verbose`, exactly zrok's `mappings` behavior.

The live surface is one lean in-place writer, not a bubbletea program: it re-paints a plain terminal scrollback of request lines and log lines (colored like zrok's panes — dim timestamps, amber addresses, colored methods) with lipgloss. It implements `io.Writer`, so `dl` re-inits with `CustomHandler = dl.NewPrettyHandler(level, dl.DefaultOptions().SetOutput(writer))` and any third-party logger in the stack is pointed at the same writer. One writer, every source, one re-paint loop. That same writer also hosts the live progress display (below), so the reference carries one in-place mechanism instead of two. The full bubbletea pane form — the shape flo and reef actually ship — lives in their repos and in `dfx/examples/dfx_example_logviewer`; the seam this reference demonstrates is backend-agnostic.

## Progress reporting

The seam that decides which channel a line of long-running work takes. `console verify <dir>` is the exemplar command: a real integrity pre-flight that walks the files under `<dir>`, hashes each (and checks a recorded hash when a `.console-manifest` is present), and drives the whole pattern end to end — multiple stages, real file and byte denominators, a `Fail` on mismatch, and a post-run summary. The infrastructure is the point; the directory is just something real to measure.

The pattern, distilled from flo and reef (which each rolled their own copy — the reference collapses it into one named seam):

- **A presentation-agnostic `Progress` interface.** The work emits a small, stable event vocabulary and knows nothing about display:

  ```go
  type Progress interface {
      Start(totalFiles int, totalBytes int64)  // open a stage, set denominators
      SetStage(stage string)
      FileStarted(op Op, path string, size int64)
      BytesCompleted(n int64)
      FileCompleted(copied bool)
      Notice(msg string)
      Fail(path string, err error)
      Done()
  }
  ```

- **The operation vocabulary has one home.** `Op` owns the in-flight label (`Label()` → hashing/copying/verifying) and the past-tense completion verb (`FileVerb(copied)` → copied/skipped, hashed/reused, verified). `copied=false` is a real state — no bytes moved, the object was already placed or its hash reused — and the word says so. Every reporter renders through these two functions, so a line in the live display, a line in the log, and a line on a wire all say the same thing.
- **A no-op reporter and a `wantsProgress` predicate.** `NilProgress` for callers that don't care, `progressOrNil(p)` to substitute it for nil, and `wantsProgress(p)` so the work can **skip effort that exists only to feed a real reporter** (reef skips its scan pre-walk when nothing is watching). The cost of measuring is not paid when nobody reads the meter.
- **Two reporters, selected by a TTY seam.** `withProgress(fn)` checks whether the display-owning surface is a terminal: if so, the live in-place reporter runs in a worker goroutine and re-paints through the shared writer above; otherwise `fn` runs against `LogProgress`, the line-oriented fallback that writes to `dl`, throttled to one line per 2s, and only narrates the in-flight file when it's large enough (`≥ 64MiB`) to spend real time. The reporter spans the whole run, so several stages share one coherent display, and the post-run summary prints **after** the display tears down so the lines land cleanly.
- **Snapshot-passing, no locks.** The worker goroutine owns the reporter; the display goroutine receives immutable `Snapshot` copies (over the writer's message channel), never shared mutable state. The live reporter throttles sends to ~40ms so a fast copy doesn't flood the display with thousands of messages a second.
- **Timing honesty.** Throughput is computed from bytes *actually streamed* (a reused file completes at full logical size having streamed nothing, so a logical rate would report absurd figures); the remaining-time estimate stays on the logical pace, which is self-consistent either way. An indeterminate stage — no denominators — renders an **empty bar with `n/a`, never a fabricated percent.**
- **The byte-level mechanism is a `progressReader`:** wrap the `io.Reader` so each chunk calls `BytesCompleted`. (It defeats `io.Copy`'s `copy_file_range`/`sendfile` fast paths; acceptable where the copy crosses devices, where those paths fall back to a buffered loop anyway.)

**The live backend is lean; the qualities are not.** Settled in design (2026-09-15): the reference renders its live display through its own in-place writer rather than a bubbletea program, on the condition that it retains every quality of the form flo and reef ship. A bubbletea program is a repaint engine, and the engine is the only part that stays per-consumer. The acceptance list for the lean backend:

- in-place repaint of a fixed region at the bottom of the screen (no alt screen) — cursor up by the region's line count, clear, redraw; the same behavior as `tea.NewProgram(m)` without `WithAltScreen`.
- the same visual wordmark: stage line (bold), overall bar, current-file line, per-phase byte bar, dim timing line, `n/a` for indeterminate stages; the same lipgloss colors; the same minimum-width clamp for narrow terminals.
- reflow on terminal resize: the writer re-reads the terminal size on each repaint tick, the lean equivalent of `WindowSizeMsg`.
- scrollback above the region: completed-file lines (green verb), notices, failures (red `!`), and `dl` lines stream above the bars and scroll naturally — the lean equivalent of `tea.Println`.
- raw-mode stdin for `ctrl+c`/`q` teardown, restored on exit.
- on `Done`: the region clears, then the caller's post-run summary prints on a clean console.
- repaint cadence: the worker throttles snapshot sends (~40ms) and the display repaints on its own tick (250ms) — c8's `teaProgress` numbers, carried over.

The structural consequence of the call: **the render function is shared, the transport is not.** The seam — and its promotion, see the roadmap card — owns a pure `View(Snapshot) string` producing the complete screen text for a snapshot, lipgloss styling included and no display runtime. Every backend, lean or bubbletea, renders that same function and differs only in how the result reaches the screen. That makes "looks the same" a code identity rather than a visual claim: a snapshot rendered by the reference and one rendered by flo are the same string.

## Tables and detail

`console list` and `console status` are the rendering exemplars, following the house pattern already established in the archive suite:

- go-pretty tables, `table.StyleRounded`, `SetOutputMirror(os.Stdout)`.
- Cell conventions: empty values render as `-`; long identifiers truncate to 12 chars with `...`; status is a word colored by state — `text.FgGreen` active, `text.FgYellow` retrying, `text.FgRed` failed — plus glyphs where the column is too narrow for a word: `✓` enrolled, `!!` limited, blank = not.
- Aggregation under the table: `t.SetCaption("%d active, %d failed")` for status-shaped tables, `total: %d` for flat lists.
- `--json` emits the raw payload through `dd` (sorted keys, deterministic — the practice's machine-output guarantee, an upgrade over zrok's `json.MarshalIndent`).
- Empty state teaches the next move: "no shares found. run `console share <target>` to create one."
- `console status` renders key-value tables, masks secrets as `<<SET>>` / `<<UNSET>>` unless `--secrets`, and writes its non-table annotations (warnings, hints) to stderr so a piped `console status` stays clean JSON-free text on stdout.

## Config lifecycle

`enable` / `disable` demonstrate the `dd` shape from the base stack note: compiled defaults → `~/.config/console/config.yaml` → `./console.yaml`, merged with `dd`, validated by `Config.Validate()`, written by `dd.UnbindYAMLFile`. `enable` generates a local account token (the miniature of zrok's enrollment) and writes the environment; `disable` removes it. `console new` is not a command here — the cascade's starter file is written by `enable`, which is the honest lifecycle for a single-user tool.

## Deferred (and why)

- **A real TUI with panes.** The scrollback writer covers the writer seam; a bubbletea program adds pane geometry, not console understanding. It belongs in `dfx/examples/dfx_example_logviewer`'s orbit, not in the reference.
- **Log files and rotation.** The reference demonstrates where logs go (stderr) and how they render; daemon file plumbing is an operations concern the practice's base stack note already covers.
- **`dl` format detection against the output writer, and `dl`'s stderr default.** Both are filed on df's roadmap (`format-detection-follows-the-output-writer`, `dl-defaults-its-output-to-stderr`; the latter requires the former). Until the detection card lands, console carries a stopgap: its stderr `dl` init resolves `UseJSON`/`UseColor` from a TTY check on `os.Stderr`, via the `JSON()`/`Pretty()`/`Color()`/`NoColor()` setters that freeze an explicit decision. The shim is marked for deletion when the detection card closes; the default-flip card needs nothing from console (its explicit `SetOutput(os.Stderr)` stays as a statement of intent).
- **A `dl` convenience for the stderr split.** A `dl.StderrOptions()`-style helper would make the reference's init one line. It is a df API question, not a console one; the stderr-default card mostly obviates it — held until the practice's own repos make the same need visible.

## Where this goes next

Once the reference is built and felt, the idioms promote to the grimoire as one convention note — `software/conventions/diagnostics-and-output` — with a stock paragraph for repo `AGENTS.md` files, plus the two footnote corrections in `AGENTS.md` and `meta/base-software-stack` (trim-prefix rule: module path plus a slash, not a git-host path). The first retrofit is reef, which is already half-conformant: the delta is message shape, trim prefix, `--json` through `dd`, and the fatal-error idiom.
