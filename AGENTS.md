# AGENTS.md — console

console is a miniature tunnel — share a local endpoint, reach it from another shell, list and inspect what is live — that exists as the practice's reference for what a good Go CLI console looks like: where diagnostics go, how tabular output renders, how a fatal error teaches the fix. The design law for every idiom lives in `docs/future/console.md` until the work lands.

## How to arrive

1. Read the newest entries in `docs/journal/` as prior-session context. The code and `docs/current/` win if they disagree.
2. Read `docs/future/console.md` — the spec is the reference itself; the idioms it names are the point of this repo.
3. `docs/future/roadmap/` holds what's ahead.

## Implementation posture

Small work runs single-agent end-to-end; anything architectural spawns a spec and enters the design-build pipeline. Substantive changes are gated by Terminus to `clean` — resolve or get an explicit veto on every finding — then stop for Michael's review. Synthesize built behavior into `docs/current/` and `CHANGELOG.md` as it lands.

## Console idioms

This repo is the standard. The rules it demonstrates are load-bearing, not incidental — do not "improve" them away:

- diagnostics go to stderr through `dl`; results go to stdout. a command never logs its output.
- `dl` format (pretty vs json) is detected against the writer the logs go to, not the terminal the program happens to run in. until `dl`'s format-detection-follows-the-output-writer card lands, `console` carries a stopgap TTY check on its stderr writer in `cmd/console`; delete the shim when the fix ships.
- fatal command errors render through `consoleui.Error`: a styled `ERROR` label, a message, a remedy as a rendered command, then exit 1. `panic` is behind `--panic` only.
- list commands render go-pretty tables to stdout, with a `--json` escape hatch that emits through `dd` (deterministic, sorted keys).
- long-running work reports progress through the presentation-agnostic `Progress` seam (`internal/progress`): the work emits events, a TTY check picks the reporter (live in-place display or the throttled `dl` line fallback), and timing figures are honest — streamed bytes for throughput, `n/a` for indeterminate stages, never a fabricated percent.
- level discipline: `Error` = this operation failed, `Info` = a state transition, `Warn` = non-fatal anomaly or skip, `Debug` = internals. message shape is operation + quoted subjects + `: %v` error tail.

## Build and test

```sh
make build
make test
make clean
```

`make build` installs to `GOBIN`; there is no frontend, so no generate step. `make test` runs the full ordinary gate: go test and vet.

## Project memory

Durable knowledge about this project lives in `docs/journal/`, dated files `docs/journal/YYYY-MM-DD.md`. This is project memory; it does not go in harness-local storage (`.claude/` or equivalent), where it's invisible to every other harness and collaborator and dies with the host. Concretely: do not write to your harness's memory directory or memory tool for this project — even when the harness presents it as the default place for durable knowledge. That tool is the silo this convention exists to replace; the journal is the only durable home.

On arrival, read the most recent entries to pick up where the last session left off, before you start changing things. Treat them as prior-session context, not verified truth — if an entry conflicts with the code or a `docs/current/` doc, the code wins.

Write the smallest entry that carries the session's durable insight, and nothing more. The test for every line: *would a competent agent get this wrong, or waste time rediscovering it, working from the tree alone?* If it's recoverable by reading the code, the diff, `docs/current/`, or git history, leave it out.

That filter keeps four kinds of thing and discards the rest:

- **Decisions whose rationale isn't visible in the result** — why a value was chosen, what a line guards against, why something that looks like dead code or a no-op is load-bearing.
- **Deliberate non-actions** — a change you considered and chose not to make, so the next agent doesn't "fix" it. An unchanged file leaves no trace in a diff.
- **Couplings that span files** — two places that must move together, an ordering that matters, an assumption one file makes about another.
- **Live state** — what's unverified, unfinished, or waiting on something external.

Skip change inventories, restatements of the diff, and play-by-play of how you worked. There's no write-time approval gate; Michael reviews on commit. Append to the day's file if it exists, and write the few lines you'd want the next agent to read — honest and self-contained.

## Commits

The operator commits; agents don't. Never run `git commit` or `git push` in this repo. Finish the edit, leave the change in the working tree (staged is fine), report what changed, and hand off — the uncommitted diff is the review queue and the commit is the operator's act of acceptance. Approval of a change is not direction to commit; only an explicit instruction to commit is, and only for that commit.

## Roadmap

This repo's roadmap lives in `docs/future/roadmap/` — one frontmatter-markdown item per file, per the roadmap convention in the grimoire (software/conventions/roadmap-convention.md). You may add items freely: write the file directly with required `title`, `state: inbox`, and `created:` (today, YYYY-MM-DD), optional `tags`/`source`/`log`, and a body that is a small, clear prompt -- the problem or solution to execute, not documentation of it; trust the code and the day's journal entry for what's discoverable, and point a `log:` stamp at the specific journal entry when a card leans on hard-won context. Everything above the first `##` heading is the prompt; supporting material that isn't the prompt goes in named sections below it (`## why` for justification, `## background` for a longer description), which are conventional, never required, and never validated. The filename is the slug of the title (lowercase ASCII, hyphens; discard every other character); never overwrite an existing file. Read sibling items for the shape.

Hard rules: never touch `order.yaml` (priority is the operator's judgment, set at triage); never commit roadmap changes unless directed — the uncommitted diff is the review queue; never delete items; edits change only the lines that express them. Label the kind from the house set when one fits: defect, documentation, enhancement, epic, feature, story; add `spike` alongside it when the work carries unknowns that need discovery.

## Project rules

- Use `github.com/michaelquigley/df/dl` for logging and `github.com/michaelquigley/df/dd` for YAML/JSON binding.
- The maintainer owns commits and pushes unless explicitly requested otherwise.
- Run `unfurl -i` on every Markdown file you author or edit.
- Prefer lowercase user-facing output. Dynamic values appear in single quotes.
- Go files use mixed-case names such as `shareCmd.go`; tests use `shareCmd_test.go`.
- Go comments start lowercase unless their first word is an exported Go identifier.
- Never leave generated binaries or test artifacts in the repository.
- Never use emoji.
