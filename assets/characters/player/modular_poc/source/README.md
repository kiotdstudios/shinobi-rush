# Source and reproducibility

PixelLab MiniMax generated the original SE sword motion. PixelLab Pixen removed isolated baked trails, and the exact pixel workbench shortened four raised-tip pixels without changing body scale. Raw sources/corrections and build_baked_reference.py reproduce the24-frame fully drawn reference.

PixelLab Pro edited the reference into weaponless underpaint in six four-frame batches; body_jobs.json records the actual jobs/input ranges. Pro changed transparent padding, so check_registration.py measures translation against original head and feet separately. Every pair agrees. export_body.py restores the original source placement using that measured offset, removes only small disconnected specks and verifies no body clipping. It never scales, warps, interpolates or recenters by a per-frame bounding box.

Separate swords were drawn with the PixelLab exact pixel workbench, not generated with the body. weapon_recipes.json contains the original transparent64×64 recipes; katana drawing a0d6d1b8-d21a-4c96-8aa6-17588d2865e7, straight-sword drawing b592c95c-f82a-4d9b-9c51-96ee74bf5391. Primary grip pivot[14,32] and native pixel scale1 are shared.

frame_anchors.json contains manually curated hand/orientation/layer tracks, reviewed against native body frames and baked blade poses. build_metadata.py validates opaque grip points and writes the opt-in contract. render_previews.py uses nearest-pixel transforms and verifies both weapons touch the grip, have binary alpha and fit the192×192 comparison canvas. Body PNGs are never replaced when changing weapons.

Art direction reference: [Sucker Punch, Mastering the katana](https://blog.playstation.com/2020/06/23/ghost-of-tsushima-mastering-the-katana/); original choreography/art only. No game assets were copied. Timing remains a proposal for Aki. This source folder is excluded from Godot import/export with .gdignore.
