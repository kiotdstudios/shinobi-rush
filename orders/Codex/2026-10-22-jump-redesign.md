# ORDER — Redesign the player jump so it fits the game (supersedes the re-cut part of the 10-21 jump order)

- Agent: Codex
- Status: QUEUED
- Priority: P1
- Owner: Codex (art), requested by Aki on the owner's instruction
- Branch/PR: new branch `codex/jump-redesign`, normal reviewed PR
- Dependencies: none for art; Aki's Body Flicker dodge (this date) is already in the game, so the jump must read clearly different from the flicker (no vanish, no streak).

## Objective
The owner played the current jump and said: "the jump animation needs to change, it doesn't fit this game". The current sheet is a 24-frame leap that Aki stretches over 0.85 s; its pose language does not match the kunai shinobi we now have. Replace it with a jump that fits: a short, grounded shinobi hop (quick crouch, tight tuck at the top, light landing) in the same 128x128, 8-direction, nearest-filtered format and the same root as the other player sheets.

Open question for the owner (answer before the full eight): what should the jump look like? Suggested default if no answer: tight tuck hop with the kunai hand kept low, no big arm flail, no spin. Provide ONE direction (SE) as a proof for approval first, same gate as the kunai order.

## Constraints
Keep the 0.85 s gameplay duration (the controller drives frames from progress, any frame count works). Feet stay on the anchor through the whole arc. `air_attack` art from the 10-21 order still applies on top of the new jump pose.

## Scope / Files owned
Player `jump` sheet and manifest entry only. No controller, camera or combat-timing changes.

## Deliverables
SE proof + report (frame count, fps), then the eight directions after approval.

## Acceptance Criteria / Tests
Manifest validates; in the live build run -> jump -> land -> run reads as one continuous motion and clearly differs from the Body Flicker dodge.

## Handoff / Notes
Until delivered the game keeps the current jump art (no placeholder is shipped).
