# console

**The shape of a good console.**

console is a miniature tunnel — share a local endpoint, reach it from another shell, list and inspect what is live — that exists to demonstrate, in running code, how a Go CLI console should behave. What logs to where. How tabular output renders. How a fatal error teaches the fix. It is a reference, not a product: the tunnel is an excuse, the console is the artifact.

Every idiom the reference demonstrates is named in [docs/future/console.md](docs/future/console.md). The idioms were distilled from zrok's controller and CLI, corrected where zrok itself drifted (diagnostics to stderr, a `--verbose` that actually works), and are the practice's standard for logging and human-oriented CLI output.

## Commands

| command | demonstrates |
|---|---|
| `console share <target>` | the live console: one writer carrying logger lines, third-party log lines, and request events; `--headless` is the log-as-UI variant; a background route refresher on its own channel |
| `console access <token>` | config cascade read, startup config dump, results on stdout |
| `console verify <dir>` | progress reporting: the presentation-agnostic `Progress` seam, a TTY-based reporter selection, live bars and a throttled log fallback, honest timing |
| `console list` | go-pretty tables, status glyphs, caption aggregation, `--json` through `dd` |
| `console status` | key-value tables, secret masking, warnings whose remedy is a rendered command |
| `console enable` / `disable` | the `dd` config lifecycle: generate, write, remove |
| `console version` | build-info reporting |

## Build

```sh
make build   # installs to GOBIN
make test    # go test + go vet
make clean
```
