# Job report — Ashen Ruins volcanic trees
- Agent: Codex
- Order: orders/Codex/2026-10-24-ashen-volcanic-trees.md
- Date: 2026-10-24
- Final status: REVIEW (technical work complete; visual approval pending)
- Commit / PR: pending implementation commit below

## Work completed
Created3original volcanic tree silhouettes for the Village Hidden in the Cinders: upright sentinel, wind-bent tree and split-trunk elder. Native320x448RGBA with shared source-to-native nearest scale and fixed160,416root anchor. Barren intricately forked branches, charcoal/slate bark, molten-red root/lower-trunk cracks, compact basalt chips. No surrounding terrain, baked shadow or flame effect.

96phase/24FPS/4second rooted wind rig preserves original source clusters. Lower70px above root remains fixed. Eight-step heat pulse affects only existing red crack pixels in lower150px. Three different phase/strength settings. Separate16distinct32x32ash-flake tumble poses; bounded24sprites/tree,8second analytic curl/drift/fade lifecycle,6FPS tumble.72sprites total; independent wind/ash/heat toggles. No per-frame allocation or unbounded particle growth.

Standalone art-review scene includes approved128px player, native scale,0.665gameplay zoom comparison, Blightwood tree comparison, clock, normal/half, pause/step controls. No existing game startup or world layout changed. GIFs contain192actual Godot Web frames:8seconds normal,16seconds half speed. No simulated replacement renderer used.

## Files changed
- assets/environment/ashen_trees/: three PNGs/imports, original sources excluded from runtime, manifest, README.
- assets/vfx/ashen_foliage/: separate ash atlas/import, original source, README.
- scripts/environment/ashen_tree.gd and ashen_wind.gdshader: new isolated reusable art component.
- scripts/art/ashen_trees_review.gd and scenes/art/ashen_trees_review.tscn: unbound review scene.
- docs/visuals/ashen-trees/: extraction/review/capture scripts, normal/half GIFs, contacts, screenshots and validation JSON.
- Own order/report only. Existing art, world, controllers, combat, collision and camera systems untouched.

## Tests performed BEFORE implementation commit
- Python docs/visuals/ashen-trees/export_art.py PASS:3transparent320x448textures, common anchor/shared scale, safe margins,16distinct ash poses. Additional decoded-pixel check:0remaining magenta-hue spill pixels on all3trees.
- Python scripts/ci/godot_ci.py import --project . --log-dir build/ashen-trees-final-import: final import run before commit; native proof below.
- Godot4.7.2 --headless --path . --script docs/visuals/ashen-trees/native-proof.gd PASS: all3textures load, anchor positions, fixed72spritepool, exact8s particle wrap, toggles hide flakes and no growth at10000s.
- Isolated review project prepared with prepare_review.py, exported via scripts/ci/godot_ci.py export --project ../ashen-trees-review-20261024 --out ../ashen-trees-web-approved-proof-20261024 --log-dir build/ashen-review-approved-proof-export: PASS. This is an ART REVIEW export, not the live game build.
- Node docs/visuals/ashen-trees/browser-proof.mjs ../ashen-trees-web-approved-proof-20261024 build/ashen-trees-browser-final: PASS. Normal/half speed ratio, pause,1/24sstep, independent wind/ash/heat, Blightwood comparison and gameplay zoom;192renderedframes; no browser errors. Read-only telemetry plus real UI clicks.
- Node docs/visuals/ashen-trees/motion-proof.mjs ../ashen-trees-web-final-20261024 build/ashen-motion-proof and decoded PNG comparisons: all9checks PASS. Upper branches change, roots pixel-identical, full wind loop pixel-identical at0/4s for each tree with ash/heat off. Same shader/asset revision as final export; later preview-only player sorting correction does not affect tree art/rig.
- Python docs/visuals/ashen-trees/make_previews.py PASS: both GIFs decode192frames,8000/16000ms, ~1.9MB each. Actual captures use fixed shared global palette without dithering.
- Visually inspected source tree/ash art, final native contact, actual renderer preview, Blightwood comparison and gameplay scale screenshot. Corrected magenta fringe during extraction and review-only player root/sort setup before final captures.
- Order structure validator and staged whitespace check before commit.

## Issues encountered
Initial matte extraction left faint magenta around twigs; widened hue-key cleanup and reran exports before final proof. Preview initially used player's texture top-left as sort position; corrected to a foot-anchor wrapper and recaptured all192frames. No remaining known technical issues. Tree motion is96shader phases, explicitly not96painted body frames.

## Generation provenance
PixelLab authenticated balance/tool capabilities reviewed; available759.80generations, credentials never exposed. Selected built-in image_gen for large isolated props and matching charred-ash sheet, followed by technical keyed transparency, shared nearest extraction and root registration. Three separate tree calls plus one coherent16pose ash sheet. No paid PixelLab generation requests. User reference establishes camera/material/silhouette; original outputs preserved for reproducibility.

## Questions for owner
None required to complete asset production. Visual review is next.

## Outstanding work / next steps
Review tree silhouettes, heat pulse and ash at provided normal/half speed. Initial art package is unbound; builder registration and live world placement not implemented or claimed. Live deployment: not applicable; existing game has no references to this art-review scene/components. PR is for visual review, no merge/deploy requested for this set yet.

Implementation commit:82fccddbf111861b540a388160ec216d85938db0
Review PR:https://github.com/kiotdstudios/shinobi-rush/pull/148 (draft, not merged).
Final import and native proof both PASS before implementation commit.

