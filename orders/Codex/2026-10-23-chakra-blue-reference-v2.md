# ORDER — Blue charge VFX from owner reference
- Agent: Codex
- Status: REVIEW
- Priority: P0 direct owner request
- Owner: Codex art
- Branch/PR: codex/chakra-blue-reference-v2; https://github.com/kiotdstudios/shinobi-rush/pull/118 (draft art review)
- Dependencies: downloaded owner CHARGE-VFX-PINK-V2.png; prior chakra/body rejected

## Objective
Use the supplied nine-frame charge effect as motion reference; create a much richer blue version with substantially more purposeful frames.
## Context / References
Owner Dropbox download, 288x32 RGBA, nine32x32 keys. Preserve upward curling energy, hollow center and ground origin. Prior rejected chakra/body work remains paused; this is a new VFX-only review candidate.
## Scope / Files owned
Versioned VFX assets, provenance, manifest, previews and art review documentation only. No player body, gameplay, movement, combat, camera or production charge binding edits.
## Deliverables
96 frames:16 buildup,64 sustained-loop frames,16 release. Transparent native256px VFX cells, timing/anchor metadata, normal/half-speed GIFs, contact sheets and review page. Preview against approved128px idle only as scale reference.
## Acceptance Criteria / Tests
Actual unique authored motion, no repeated-frame padding or synthetic interpolation, blue-white palette, transparent center, fixed ground origin, clean sheet boundaries, no baked character/floor/shadow, seamless sustained loop; file/alpha/uniqueness/timing QC and browser playback. Commit/report/PR after verification. No production replacement until owner reviews candidate.
## Handoff / Notes
Builtin image generation for creative artwork; deterministic extraction/chroma/nearest scaling/compositing only. PixelLab reviewed as optional; no claim of PixelLab generation.

## Review delivery
Commit bb8dde498b526a9fe56a13fe9cff5994fc2ec504. All96 frame/GIF/native-load/browser checks passed. Public normal/half-speed previews and asset ZIP in PR118. No runtime binding or live game change; awaiting owner visual feedback.
