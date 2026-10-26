# Per-agent git worktrees — Shinobi Rush

## Why
Shinobi Rush previously had a single shared checkout at `Documents/GitHub/shinobi-rush` used
concurrently by multiple agents (Orcha, Aki, Kiro, Codex). This caused real, repeated collisions
during live multi-agent sessions on 2026-10-24/25:
- A `git checkout`/`pull`/`branch` operation by one agent running while another agent's
  `godot_ci.py` test process was mid-run against `--project .` in the same folder (live test read
  corrupted mid-switch).
- A `.git/index.lock` left behind by an interrupted `git stash pop` (killed mid-operation by a
  command timeout) blocked ALL git operations in the shared folder for 45+ minutes, for every
  agent, until manually diagnosed as stale and cleared.
- Another agent's uncommitted working-tree edits (art/manifest changes, a file deletion, new asset
  folders) sat in the exact same folder as a different agent's in-progress commit, requiring manual
  `git add <file> <file> ...` by explicit name instead of `git add -A` to avoid accidentally
  committing someone else's unfinished work.

This mirrors the exact problem Driftbound solved with per-agent worktrees
(`overcharge-aki`, `overcharge-kiro`, `overcharge-orcha` alongside the base `overcharge` checkout).
Shinobi Rush now has the same layout.

## Layout
One shared `.git` object database (`Documents/GitHub/shinobi-rush/.git`), with one additional
**isolated working directory per agent**, each a real `git worktree`:

| Path | Agent | Initial state |
| --- | --- | --- |
| `Documents/GitHub/shinobi-rush` | shared/base (Chief's own checkout) | tracks whatever branch was last used here |
| `Documents/GitHub/shinobi-rush-orcha` | Orcha | detached HEAD at `origin/main` |
| `Documents/GitHub/shinobi-rush-aki` | Aki | detached HEAD at `origin/main` |
| `Documents/GitHub/shinobi-rush-kiro` | Kiro | detached HEAD at `origin/main` |
| `Documents/GitHub/shinobi-rush-codex` | Codex | detached HEAD at `origin/main` |

Each worktree is a full, independent working directory (its own `project.godot`, its own files on
disk) but shares the same object store, remotes, and branch history — no extra network clone, no
duplicated history, and a push from any worktree is immediately visible to all the others via a
normal `git fetch`.

**Git enforces that the same branch cannot be checked out in two worktrees at once.** Each
per-agent worktree therefore starts in *detached HEAD* at `origin/main`'s tip, not on a named
branch — this intentionally avoids claiming `main` (or any other branch) exclusively. Starting a
real task still follows the existing convention exactly as before:

```
cd Documents/GitHub/shinobi-rush-<youragent>
git fetch origin
git checkout -b <youragent>/<task-slug> origin/main
# ... work, test, commit, push ...
```

## Rules
1. **Use your own worktree folder for your own work.** Never edit files in another agent's
   `shinobi-rush-<agent>` folder.
2. The base `shinobi-rush` folder remains available for the Chief/project owner's own direct use.
   Agents should prefer their dedicated worktree over the base folder for day-to-day order work.
3. Before any `git checkout` / `pull` / `branch` operation on a worktree, it is still good practice
   to check for a stuck lock (`Test-Path .git/index.lock` from within the worktree) — the shared
   `.git` directory is still shared infrastructure, even though working directories are now
   isolated. A worktree being isolated prevents *file checkout* collisions; it does not create a
   second physical repository, so index/ref-level git operations still briefly touch shared state.
4. Adding/removing a worktree (`git worktree add` / `remove`) is a repository-wide operation —
   coordinate before restructuring this layout again.
