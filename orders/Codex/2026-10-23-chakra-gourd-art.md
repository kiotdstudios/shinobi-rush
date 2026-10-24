# ORDER — PixelLab blue chakra gourd
- Agent: Codex
- Owner: Codex art
- Status: REVIEW
- Priority: P0 direct owner request
- Branch/PR: codex/chakra-gourd / https://github.com/kiotdstudios/shinobi-rush/pull/136 (draft); implementation95dd8a0
- Dependencies: existing health gourd and supplied blue ceramic reference

## Objective
Recreate the supplied blue chakra gourd in the current health-pickup pixel style, with matching sway, blue glow, sparks and floor-light presentation.
## Context / References
Owner requests PixelLab explicitly. Existing health_gourd body17frames, glow1 and ember9; body14FPS, glow/ember12FPS plus bob/pulse/orbit. Reference has weathered blue/teal ceramic, gold wear/cracks, cork and red cord/tassel.
## Scope / Files owned
Art package, separate body/glow/spark layers, timing metadata, normal/half-speed previews and integration notes. Existing health gourd and gameplay/controller behavior remain unchanged. Art review delivery before binding a new pickup into gameplay.
## Deliverables
PixelLab-generated blue gourd and animated layers, transparent PNGs, manifest/provenance, review preview and contact sheet, native texture import/QC, browser review checks, own report and draft art PR.
## Acceptance Criteria / Tests
Matches health-gourd pixel scale and presentation; clearly blue ceramic/aura; red cord and cork retained; sharp pixels, transparency, stable frame canvases, controlled sway, no clipping; separate effects. Verify files, timing and loops, actual review rendering; label generation sources honestly.
## Handoff / Notes
No new chakra VFX surrounding the player; this is a separate pickup asset. Live deployment not applicable until owner accepts new art and requests gameplay pickup integration.

Completed26transparent-frame review pack:16timed body keys (7distinct raster poses),1blue glow,9exactly palette-mapped spark frames; PixelLab-only art authoring. Body keeps75px painted height on padded64×96canvas. Normal/half previews, ZIP, manifest, native import and desktop/phone browser review passed. See own report.
