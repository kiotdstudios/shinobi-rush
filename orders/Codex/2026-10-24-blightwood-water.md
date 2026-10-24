# Order - Blightwood flowing river and small waterfall
- Agent: Codex
- Owner: Codex
- Status: DONE
- Priority: P1 - latest owner request
- Branch: codex/blightwood-water
- Dependencies: PixelLab active; approved forest palette and existing diamond grid available.

## Objective
Recreate only the clear-blue river water and small waterfall in the owner's reference, with high-detail flowing motion. Keep later lilies, flowers and rocks separate and absent from this pack.

## Context / References
Owner clipboard image codex-clipboard-13158944-346a-49ab-8990-251dae3f93ce.png. Elevated three-quarter camera, Blightwood environment. Pixel Art Animator and reviewed PixelLab API workflow. Existing 72x36 ground grid.

## Scope / Files owned
New assets/environment/blightwood_water, own animation/runtime/review scripts, own tests/previews/report. Minimal builder catalog and visual integration only. No combat, camera, swimming, collision or map-layout redesign. Existing historical queued character/wall work remains outside this latest direct request.

## Deliverables
Transparent modular river tiles, falling-water and landing-foam layers, animation timing/anchors/provenance, normal and half-speed previews, builder category, tested reviewed PR and live verification where runtime integration succeeds.

## Acceptance Criteria / Tests
Detailed readable continuous flow, crisp native pixels, registered looping frames, seam-safe adjoining water tiles, clear blue palette, no baked scenery. Validate assets, Godot import/native tests/Web export, actual browser animation and builder persistence. Record exact deployment identity and failures honestly before DONE.

## Validation and PR
Implementation3337643, integration2b892cf; PR https://github.com/kiotdstudios/shinobi-rush/pull/162. Integrated native2393 PASS; 12builder browser checks and10review checks PASS. Actual192-frame normal/half previews published. Await required CI/main deployment and exact public-browser verification before DONE.

## Verified live delivery
Runtime merged as 0921f13afc8f3bf036e468e7661103eba662ca0f via PR #162. Main Godot CI https://github.com/kiotdstudios/shinobi-rush/actions/runs/40103801393 including deploy and smoke-postdeploy PASS. Canonical builder verified 2026-10-24T14:53:27.185Z; 12/12 checks PASS. Interactive water review verified 2026-10-24T14:53:00.764Z; 10/10 checks PASS. Both returned the exact runtime SHA, with zero errors. Evidence and exact URLs in docs/visuals/blightwood-water/live-*-validation.json. Delivered for owner art review; no owner visual approval claimed.
