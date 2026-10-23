---
name: retro
description: End-of-session retro. Records this session's friction (turns, time, tokens lost) into retro/ files, checks whether earlier fixes actually stopped their friction, and recommends one old backlog row. Use when the developer types /retro or asks for a retro, and offer it when a unit of work finishes and before any /clear.
---

# Session retro

Run these four steps from **this session's own history**. Do not reconstruct
other sessions. Read `retro/backlog.md` and `retro/log.md` first.

**When to offer:** when a unit of work is finished and written up, offer it in
one line. Run it before any `/clear`.

## 1. Friction
List what cost turns, time or tokens: a wrong or missing file/route, a rerun,
a false pass or false fail, a stale doc or fact, a command that failed, repeat
exploration, oversized context. Name each concretely (file, command, count).
None: say so and skip to step 3.

## 2. Route each item
First match wins. No duplicates.
- Fixable now in a line or two (stale fact, wrong path, missing note in the
  instructions file): fix it.
- A defect in the code or tooling, not fixed this session: add to `retro/issues.md`.
- Matches an existing `retro/backlog.md` row: append an `Evidence YYYY-MM-DD:` line to it.
- New process or cross-cutting improvement: a new `retro/backlog.md` row using
  `retro/_templates/backlog-item.md`. **Max 3 per session**, highest leverage first.
- Changed what the project believes (a rule, a reversal, a chosen approach and
  why): add an entry to `retro/decisions.md`.

## 3. Outcome check
Read `retro/log.md` lines with a `Measure:` clause dated in the last 30 days.
If this session hit friction a `Measure:` says should be gone, append
`(recurred YYYY-MM-DD: what happened)` to that log line, and add an Evidence
line to a matching backlog row, or open a new row. The fix did not pay off.

## 4. Report
Short. Nothing longer than:
- What was written, one line per destination.
- `Measure:` checks that recurred, or "none recurred".
- **Pick next:** the oldest `queued` backlog row older than 14 days, with one
  line on why it is still worth doing, or say it should be dropped.

## Closing a backlog row
When a row is built or dropped: append one line to `retro/log.md` and delete
the row. A shipped row's log line carries `Measure:` (the friction that should
stop recurring, stated so a later session can check it, e.g. "Measure: no
rerun of the full test suite after a lint-only change"). Before working a row,
set its status to `intaking` so a concurrent session sees it is taken.
