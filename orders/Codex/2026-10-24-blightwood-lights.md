# Order - Blightwood Forest lighting decor
- Agent: Codex
- Owner: Codex
- Status: REVIEW
- Priority: P1 - latest direct owner request
- Branch: codex/blightwood-lights
- Dependencies: PixelLab authenticated, existing approved forest/grass palette and camera; satisfied.

## Objective
Recreate all five reference decor silhouettes with high-detail blue illumination, flicker and separate glowing flying forest fireflies, following the previous fire-pack delivery workflow.

## Context / References
Owner image573BBE00-8961-4B45-9471-98F07DC00980/1-Photo-1.jpg. Wooden lantern post, stone pagoda lantern, flowering branch lantern, mossy stone brazier and root/stone spirit totem. The supplied forest/blue palette is combined with colors sampled from live grass9_center.png. Previous approved world scale, nearest pixels and three-quarter camera retained.

## Scope / Deliverables
PixelLab transparent fixture assets and separate spirit-flame/firefly animation atlases; deterministic bounded firefly emitter, separate glow/illumination/flame layers and hanging-lantern secondary movement. Five builder props plus separately placeable forest fireflies, dedicated filters, normal/half-speed Godot Web previews, manifests, tests and report. Minimal editor catalog/integration files only; no combat or camera edits. No automatic map repaint.

## Acceptance Criteria / Tests
Faithful fixture construction, crisp transparent pixel art, sampled palette, consistent native scale/root anchors and Y sort. Independent animated lighting and fireflies around every fixture. Repeatable import, native/component tests, Web export, real browser controls/effects/persistence checks, verified PR/main/live deployment and report.

## Handoff
This latest owner request is the active scope; historical queued combat/jump/wall requests remain outside this asset batch. Use existing reviewed integration pipeline. Do not represent the supplied concept panels as production sprites.

## Local validation
2301native checks PASS,16builder browser checks PASS,13review controls/effect checks PASS,192actual frames in each preview (8s normal/16s half). Upstream fence update will be integrated and retested before publishing.
