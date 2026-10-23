# Charge body — player and bandit

Body-only review revision: wide planted squat, joined upright hand seal at chest, elbows out and restrained breathing. No aura, weapon, floor shadow or controller changes. Rejected chakra V1/V2 are not part of this package.

Open `review.html` through a static server at the repository root. Both characters appear together; default playback is half speed, with direction buttons, pause, stepping and a frame scrubber. Each direction also has normal and half-speed GIFs. `directions-contact.png` shows all headings.

## Integration

Use `manifest.json`: 128×128 RGBA; root (64,116); 16 looping frames; 12 FPS, or 6 FPS for the owner's preferred half-speed review. Frames are in `assets/characters/{player,bandit}/charge_body/frames/{direction}`. Atlases use a 4×4 row-major grid of 128px cells. Western views mirror the matching eastern body around x=64; no weapon attachment is included. Effects remain independently timed layers.

This is an unbound art candidate, awaiting visual review. It does not change the production sprite-library manifest, gameplay, AI or camera. Gameplay owners should bind the charge hold only after approval and synchronize entry/release to their existing charge state. No attack contact or hitbox frames apply to this hold.

Generated original keys were processed only by chroma removal, fixed-cell nearest reduction, translation to the foot anchor and native western mirrors. No per-frame size fitting, optical-flow interpolation or synthetic duplicate padding. QC records source hashes and translations. Original concept loops are retained under ignored source folders for provenance; they are not production frames.

## Rejected effects archive

Desktop: `Shinobi Rush - Chakra VFX Giveaway - 2026-10-23`. Public V1/V2 VFX-only ZIPs exclude character and supplied reference images. Private originals are separate. `verified-sha256.json` records 273 verified files. Old review PRs #107/#118 were closed as rejected; no rejected effect was deployed.

## Checks

Run `export.py`, `validate.py`, `browser-proof.mjs`, Godot CI import, and Godot headless `native-proof.gd`. Browser checks cover desktop and phone viewports, every heading/key, pause and normal/half timing. Screenshots are viewport emulation, not physical-phone testing.
