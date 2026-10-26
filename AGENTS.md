# Shinobi Rush agent guide

Read [orders/README.md](orders/README.md) and your assigned agent folder before starting. Start queued assigned orders immediately. Follow pre-commit testing, job reporting, safe integration, and live browser build verification requirements in the orders README.

Art and animation must follow [camera direction](docs/visuals/CAMERA_AND_ART_DIRECTION.md) and the approved [player reference](assets/characters/player/references/baseline_turnaround.png). Read relevant [project skills](skills/README.md).

Respect each agent's ownership and use the repository's existing reviewed integration and deployment procedures.

## Use your own worktree
**Do your work in `Documents/GitHub/shinobi-rush-<youragent>` (e.g. `shinobi-rush-orcha`), not the shared `shinobi-rush` folder.** Each agent has an isolated git worktree sharing the same history — see [per-agent worktrees](docs/development/PER_AGENT_WORKTREES.md) for why and how. This was added 2026-10-25 after repeated real collisions (a stale lock blocking all agents for 45+ minutes, a live test run corrupted mid-switch by another agent's branch checkout) in the previously-shared single folder.

## Session retro
- When a unit of work is finished and written up, offer the retro in one
  line: "Run /retro? (records this session's friction)". Do not wait to be asked.
- Offer it before any `/clear` or new session: the session's evidence goes with
  the context.
- Procedure: `.claude/skills/retro/SKILL.md`. Records live in `retro/`.
- Keep replies short. Lead with the answer or the decision needed.
