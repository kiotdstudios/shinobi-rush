# ORDER — Bandit alert / threaten / kunai attack / flicker-retreat art

- Agent: Codex
- Status: QUEUED
- Priority: P1
- Owner: Codex (art), requested by Aki (Level 1 Bandit robber order)
- Branch/PR: new branch `codex/bandit-action-art`, normal reviewed PR
- Dependencies: Aki PR "Level 1 Bandit robber" merged (state machine and timings below are final for Level 1); kunai direction per `orders/Codex/2026-10-21-kunai-primary-combat-animation.md`

## Objective
The Bandit plays only `idle`, `run`, `sprint` (128x128, 8 directions). Gameplay uses them for everything, with code-drawn overlays for tells. Replace those stand-ins with authored clips, same 128x128 canvas, foot anchor and scale as `bandit_128.art.json`:

| Clip | When it plays | Timing from gameplay | Notes |
| --- | --- | --- | --- |
| `walk` (or slow `run`) | PATROL, SEARCH, RETURN | 130-190 px/s | currently the run cycle at 40-60% speed |
| `alert` | NOTICE | 0.65 s hold | head snap toward the player, weight shift |
| `threaten` | THREATEN | 0.95 s then loop | menacing idle, kunai held low |
| `attack1` / `attack2` | ATTACK | windup 0.42 s, active 0.10 s; swing 2 windup 0.34 s, active 0.10 s, gap 0.20 s | one-handed kunai slashes, readable windup pose |
| `attack_recover` | after swing 2 | 0.38 s (0.85 s when overcommitted) | off-balance recovery |
| `flicker_tell` | RETREAT telegraph | 0.35 s | crouch / hand seal before vanishing |
| `search` | SEARCH | 3.2 s | looks left and right |

Body Flicker hop VFX comes from Orcha (`assets/vfx/body_flicker`), not from this order.

## Scope / Files owned
`assets/characters/bandit/**` and the art manifest only. Aki maps clip names to states in `scripts/enemy/bandit_visual.gd`.

## Deliverables
One-direction proof (SE) for approval first, then all eight, plus a report with frame counts and fps.
