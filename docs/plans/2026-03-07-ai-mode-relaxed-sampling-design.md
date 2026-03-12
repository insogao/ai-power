# AI Mode Relaxed Sampling Design

## Context

The current `AI Mode` is too strict for real text-centric AI workflows.

Today it relies on:

- CPU usage
- network throughput
- disk throughput

with a `10s` consecutive-entry threshold. That works for downloads, builds, and model loading, but it can miss lighter AI terminal usage such as streaming text responses where traffic and CPU stay modest.

The goal of this iteration is not precision. It is to reduce false negatives during real AI work, while collecting enough raw data to tune the behavior later.

## Product Direction

`AI Mode` should become a relaxed hybrid detector:

- keep the existing system signals
- add keyword-based AI/developer tool detection
- keep the machine awake conservatively once activity is observed
- exit only after a longer quiet period

At the same time, the app should write a verbose debug log so real user sessions can be analyzed afterward.

## Detection Model

### Inputs

The detector should consider four classes of signal:

1. CPU
2. Network
3. Disk
4. Process keyword hits

### Entry

The app continues sampling every second.

The system evaluates short windows of activity and may enter the “active” state if any of these are true:

- CPU window indicates sustained activity
- network window indicates sustained activity
- disk window indicates sustained activity
- a configured keyword matches a running app/process candidate

### Exit

Exit should be much slower than entry.

The user requested a “sample, then wait, then sample again” model. The simplest implementation that preserves that intent is:

- maintain per-second sampling
- aggregate that into a rolling minute-level activity result
- if five consecutive minute windows show no signal at all, exit keep-awake

That gives a practical five-minute grace period.

## Keyword Strategy

The app should expose:

- a default built-in keyword list
- an additional user-defined keyword list

Matching remains intentionally fuzzy:

- lowercase comparison
- substring match against localized app name, bundle id, or executable name

This is not meant to identify exact process names. It is meant to avoid missing common tools such as:

- `codex`
- `claude`
- `cursor`
- `code`
- `vscode`
- `terminal`
- `iterm`
- `ollama`

## Debug Logging

For this phase, logging should record raw observations, not only final decisions.

Each sample record should include:

- timestamp
- mode
- CPU value
- network value
- disk value
- raw keyword hits
- whether a short activity window fired
- whether keep-awake stayed active
- why the decision was made

This log is intentionally verbose and debug-oriented. It can live in a temp or application support location for now.

## UI Scope

The first implementation should keep the UI minimal:

- show the built-in keywords in `Debug`
- show any custom keywords in `Debug`
- provide a lightweight add-keyword action in the panel

This does not need a polished settings screen yet.

## Manual Validation

1. Start a long AI terminal session.
2. Note the approximate start and end times.
3. Collect the debug log.
4. Compare the timeline against:
   - CPU values
   - network values
   - disk values
   - keyword hits
   - active/inactive transitions

This data becomes the basis for later threshold tuning.
