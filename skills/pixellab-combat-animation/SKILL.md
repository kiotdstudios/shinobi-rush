---
name: pixellab-combat-animation
description: Controlled PixelLab API workflow for premium 128x128 ninja combat/jutsu animation with pose-first planning, smear frames, alignment QA and Godot handoff.
---
# PixelLab Combat Animation — Shinobi Rush

For Aki or Codex art tasks. Orcha is not assigned art work.

## Read first
- `skills/three-quarter-game-art/SKILL.md`
- `docs/visuals/PIXELLAB_API_ART_PIPELINE.md`
- `docs/visuals/CAMERA_AND_ART_DIRECTION.md`
- `assets/characters/player/player_128.manifest.json`
- `https://api.pixellab.ai/v2/llms.txt` and current `https://api.pixellab.ai/v2/docs` before making requests. Never guess request fields or model response shapes.

## Non-negotiable constraints
- Existing approved ninja identity, faux-isometric perspective, eight-direction conventions, 128×128 transparent RGBA production frames, consistent 104px-ish body scale and manifest foot anchor (verify exact values), pixel-perfect nearest-neighbor output.
- No new character design, masks, cape, weapon straps, blurry motion blur, or interpolated subpixel edges.
- No edits to Kiro camera/occlusion or Aki movement/combat systems.
- Never expose or commit the PixelLab token. Read from environment/secret store only; no token in logs, reports, URLs or Git. Stop if no authorized token is available.
- Budget gate: check account balance and current endpoint costs; prepare a cost estimate; **do not submit paid generation until owner explicitly authorizes the budget and API usage**. No bulk eight-direction generation before one-direction approval.

## Pipeline (one-direction proof of concept)
1. **Asset audit.** Inspect actual source frames, sprite manifest, palette, foot anchor, existing VFX and any PixelLab IDs. Use existing character frame as reference, not a text-only replacement. Verify that API references accept the source format. PixelLab recommends `POST /unzoom` for upscaled source art; do not blindly alter native true-pixel 128×128 originals—compare pixel grid and only unzoom when needed.
2. **Pose storyboard first, no API cost.** Draft 6–8 thumbnails/poses: running approach, readable sign pose A, one smear/multiple-hands frame, contrasting pose B, lightning charge, crouched acceleration, piercing thrust, follow-through. Keep leg motion continuous during signs. Use 2–3 distinct hand silhouettes, NOT literal anatomical Naruto sign-by-sign fidelity.
3. **Plan frame rhythm.** Suggested 24fps, 16–24 total frames with uneven holds. Attack contact may happen within 1–2 frames after a lightning flash. Mark anticipation, extremes, overshoot, frame omission, smears, follow-through. Fast action must feel immediate, not sluggish. Split into short clips where an endpoint supports at most 16 frames.
4. **Select API route after reading live schema.** Prefer `POST /animate-with-text-v3` for start-frame-guided short motion (up to 16 frames, max 256px per official docs); test `POST /animate-with-skeleton-v3` (3–15 frames) only if pose control is needed and skeleton keypoints fit. Use `POST /estimate-skeleton` when needed. `POST /edit-animation-v2` is optional for consistent localized edits. For original VFX use appropriate transparent image/animation route. Do not create a new character through `create-character-v3` unless owner authorizes redesign (default: prohibited).
5. **Generate minimally.** First make one short hand-sign sequence using an approved existing direction and start frame; then one lightning/thrust sequence only if first passes QA. Save endpoint, redacted request metadata, job ID, reported usage, and source hash. Async jobs: poll documented background-job endpoint until completed; handle 401/402/422/429 and abort on repeated failures; never retry paid calls automatically.
6. **Visual QA before expansion.** Build nearest-neighbor contact sheet and GIF/video preview at 1x and approved close camera scale. Check identity/palette, transparent background, 128×128 dimensions, foot anchor drift (aim <=2 px except deliberate airborne/thrust displacement), frame-to-frame limb consistency, silhouette readability, no duplicate or malformed frames, no ghosted limbs unless deliberately marked smear frame, lightning correctly attached to dominant hand.
7. **Hybrid layering.** Keep lightning, trails, impact bursts as separate transparent VFX when possible. If hands/body cannot be cleanly composited, use a few full-body key poses; do not regenerate 847 locomotion frames. Separate physical root motion (Aki) from sprite visual offsets; provide frame events `sign_start`, `charge_start`, `thrust_start`, `hit_active`, `recover`.
8. **Deliver prototype, not a full production move.** Include source frames, PNGs, frame-timing manifest, contact sheet, animated preview, PixelLab usage/cost summary, comparison to existing ninja, Godot import notes, and a report. Aki integrates gameplay. Owner approves before expanding directions or spending more.

## Prompt scaffold (adapt to actual API schema)
"Animate the PROVIDED approved Shinobi Rush ninja, same face, clothing, silhouette, palette, perspective, and pixel cluster style, on a transparent 128x128 canvas. The ninja CONTINUES SPRINTING FORWARD while upper arms snap through two contrasting stylized ninja hand-sign poses. Include a deliberate one-frame multiple-arm smear conveying supernatural hand speed; crisp nearest-neighbor pixels, stable body size and foot position, no idle pose, no costume changes, no added weapon, no background, no blur. End in a forward-leaning lightning-charge preparation pose. Preserve lower-body running cadence."

Separate thrust clip: "From the provided approved charge pose, blue-white electrical arcs gather in the forward hand; minimal anticipation, sudden exaggerated forward piercing arm thrust with a one-frame speed smear, crisp impact silhouette and delayed cloth/electric follow-through. Same ninja identity and perspective, transparent pixel art, no background."

## Acceptance gate
A viewer at live gameplay zoom immediately reads "running ninja -> super-fast signs -> Chidori charge -> lightning thrust" with no idle pause. If generation fails identity or anchor QA twice, STOP and report, do not burn credits. No claims of live integration without Aki's verified Godot/browser test.
