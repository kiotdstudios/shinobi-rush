# ORDER -- World Builder "PUBLISH" button: commit + push layout to GitHub (desktop only)
- Agent: Orcha
- Status: DONE
- Priority: P1 -- direct owner request
- Owner: Orcha (runtime/tooling)
- Branch/PR: orcha/publish-to-github
- Dependencies: none

## Objective
Owner: "save button needs to commit and push straight to github all new level changes."

## Security note (handled before any code was written)
The owner's first version of this request included pasting a live GitHub personal access token in
chat and asking for it to be saved in browser storage so the Web-exported (publicly playable) game
could call the GitHub API directly to push commits. That was declined and NOT implemented in any
form: embedding a repo-write credential inside a page anyone can load means every visitor can
extract it from devtools/view-source and get push access to the repo, regardless of which specific
token value is used -- the mechanism itself is unsafe, not just that one key. The owner confirmed
(09:55) the follow-up proposal instead: a desktop/editor-only feature using the machine's own
already-configured git login, never reachable from the Web export, no token anywhere.

## What shipped
1. **`WorldEditor.publish_to_github()`** (new): desktop/editor only. Writes the current World
   Builder layout to a REAL file tracked by git (`res://data/world_layout.json`), then runs
   `git add` / `git commit` / `git push` via `OS.execute`, using whatever git identity is already
   configured on that machine (SSH key, Windows credential manager, or `gh auth login`). No token is
   read, stored, or embedded anywhere in this change.
   - **Web-export gate, in two places**: the function's own first line is `if
     OS.has_feature("web"): return false` (OS.execute has no effect in a Web export anyway, but this
     makes the gate explicit and testable); the "PUBLISH" button itself is only ever CREATED when
     `not OS.has_feature("web")` -- it does not exist in the scene tree at all on Web, it isn't just
     hidden/disabled.
   - **Scoped writes, no accidental scope creep**: `git add -- <path>` and `git commit -- <path>`
     both pass the exact single file as an explicit pathspec, never `-A` or `.` -- this can never
     stage or publish unrelated work-in-progress changes elsewhere in the repo, even if something
     else happened to already be staged.
   - **No bypass of repo protections**: does not force-push, does not retry past a rejection. If
     `main` requires a PR (as this repo's branch protection does), a rejected push is reported to
     the user plainly ("PUBLISH FAILED (push): ...") rather than silently failing or trying to work
     around it.
2. **`PlacedObjects.load_default_from_repo()`** (new): the "updates live in-game" half of the
   request. A fresh boot with no per-machine `user://` save yet now falls back to loading whatever
   layout was last published (`res://data/world_layout.json`), instead of only the hand-authored
   defaults -- so once a published layout is committed and the site redeploys, every NEW player sees
   it. Never overrides an existing per-machine save (that would silently discard a player's own
   local World Builder edits).
3. `tools/gen...` n/a; `tests/test_publish_to_github.gd` (new, 16 assertions).

## Acceptance Criteria / Tests
- Full suite: 2039/0 (session start) -> 2055/0, zero regressions.
- **Deliberately did not run a real `git commit`/`git push` or touch the real tracked
  `res://data/world_layout.json` in any automated test** -- `publish_to_github()` has real side
  effects (writes inside the actual repo, pushes to the actual remote) that must never happen
  inside CI. Instead: extracted the exit-code/output interpretation into pure, static
  `_commit_outcome()`/`_push_outcome()` helpers and tested every branch (success, benign "nothing to
  commit" no-op, real failure, rejected/protected push, long-message truncation) against synthetic
  inputs with zero git execution; `load_default_from_repo()` takes an optional `path` override so
  tests exercise it against a scratch `user://` file, never the real repo path; the Web-export gate
  is confirmed present at the SOURCE level (both call sites) since `OS.has_feature("web")` can't be
  toggled at runtime in a native CI run.
- Real Web export + browser smoke (`controls-probe.mjs`): `VERDICT PASS`, 0 console errors. A
  dedicated check confirmed the PUBLISH button and the word "PUBLISH" do not appear anywhere in the
  Web build at all.

## Handoff / Notes
- First use requires git already configured on that machine (SSH key or `gh auth login`) -- this is
  a one-time per-machine setup the owner does themselves; nothing in this change sets that up or
  needs to.
- `res://data/world_layout.json` does not exist until the owner clicks PUBLISH for the first time;
  until then the game behaves exactly as before (hand-authored defaults only).
