# ORDER — Player and Bandit damage animation pack
- Agent: Codex
- Owner: Codex (art); gameplay integration remains with Aki
- Status: REVIEW � local asset/native/browser checks passed; PR/live art review pending
- Priority: P1 — latest direct owner request
- Branch: codex/damage-animation-pack
- Dependencies: Existing approved player/bandit sprites and manifests; PixelLab available.

## Objective
Create hit reactions, knockback and death animations for both approved characters across the existing eight directions.

## Context / References
Existing128x128 player and red-scarf bandit idle frames; approved player baseline turnaround. Both manifests currently lack all three damage actions. Preserve identity, camera, scale, transparency, no baked shadow, and anchor64,116.

## Scope / Files owned
Codex owns new character art, damage timing/event metadata, manifests, review scenes and animation previews. Do not modify Aki's damage, HP, movement, respawn or death rules. In-place knockback artwork accompanies gameplay-controlled world displacement. Explicit handoff will distinguish art delivery from gameplay wiring.

## Deliverables
Hit_react, knockback and death for player and bandit, eight supported headings each. Transparent PNG frames, manifest metadata, normal/half-speed review, native/browser QC, PR and job report.

## Acceptance Criteria / Tests
Distinct recoil, heavy stagger/recovery and final prone death. No neutral loop posing in place of actions. No clipping, size drift, padding jitter or weapon invention. Death holds last frame instead of restarting. Preview against gameplay camera, verify Godot imports, exact frame counts, non-loop playback and directional coverage. Public review after normal protected integration/deployment.

## Audit / Handoff
Player manifest has idle/walk/run/sprint/jump/dodge/light1/light2/light3/dash_attack/charge; bandit has idle/run/sprint/light1/light2/light3/dash_attack/kunai_guard/throw/charge. No dedicated damage art in either. Planned IDs: hit_react, knockback, death. Current player defeat respawns immediately; exposing a death duration requires Aki's gameplay integration rather than silently changing that rule. Latest direct task takes precedence over historical queued art orders.
