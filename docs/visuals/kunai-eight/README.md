# Eight-direction shared kunai attacks

Owner requested this expansion after pausing/rejecting both chakra layers. Chakra PR107 stays draft and is excluded here.

Player and bandit each have light1, light2, light3, dash_attack and guard in S/SE/E/NE/N/NW/W/SW. This is384 body-frame references:24 approved player SE references reused verbatim plus360 new PNG exports, including mirrored western facings. W mirrors E, NW mirrors NE, SW mirrors SE about the native x64 anchor. These are not384 separately painted drawings.

## Playback and integration

Open `?kunai=directions` for both characters together, default half speed. Choose heading, combo or individual attack; Pause and Step advance exact authored keys. Body, Blade and Trails can be isolated. Normal gameplay uses the same data and renderer.

`assets/combat/kunai/kunai-combat.art.json` is the shared profile/per-skin pose source. `KunaiCombatData.frames(character,direction,action)` requires a literal heading; there is no SE fallback. Each key carries body path, hand pixel, blade angle, front/behind layer, phase, duration and independent swipe metadata. `KunaiWeaponVisual` binds the same black kunai texture/pivot and hand-occlusion patch to either skin. Behind/front ordering stays within the character's Y-sort plane.

The player body and weapon sample the actual AttackDef phase/timer together. Hitstop naturally holds the selected key. Bandit playback stretches the same keys over its existing attack windup/active/recovery windows. Existing AI still chooses its existing two swings; all three hits and dash are available through `BanditVisual.show_attack_pose(action,direction,phase,progress)` for future profiles. This change does not give the enemy a new combo or change damage, movement, combat windows or camera behavior. Locomotion, interruptions, set switches and death clean up the complete attachment layer.

| Clip | Keys | Source duration | Contact | Active keys | Recovery keys |
| --- | --- | --- | --- | --- | --- |
| light1 |6|300ms|2|2–3|4–5|
| light2 |6|350ms|2|2–3|4–5|
| light3 |6|483.333ms|2|2–3|4–5|
| dash_attack |5|400ms|2|2|3–4|
| guard |1|400ms loop|—|—|—|

Indices are zero based. Frames0–1 are startup; existing gameplay definitions own contact windows, cancel rules and enemy cadence. Manifest FPS remains the source average; phase-driven gameplay overrides the free-running body clock so slower bandit windups stay aligned.

## Art and verification

Native128×128 RGBA, hard alpha, fixed metadata foot anchor(64,116), separate weapon/trail, original production palette and nearest sampling. Uniform scale per complete source sheet preserves natural body rotation/crouch rather than fitting every frame's bounds. The approved legacy SE soles retain their original exclusive bottom116/117 convention; new sources use116. There is no deliberate floor shadow.

Raw builtin image-generation receipts and hashes are in `raw-receipts.json`; `sources.json` records selected keys and hand-measured tracks. Rejected iterations are retained as source provenance and excluded from runtime by `.gdignore`. No reference video frames are shipped as artwork. Source processing is chroma removal, extraction, uniform nearest scaling, palette matching, anchor registration and native mirroring.

Run `python docs/visuals/kunai-eight/validate_pack.py` for all384 references, transparency, dimensions, grips, uniqueness and unchanged SE records. `export_pack.py` rebuilds assets/manifests from the measured configuration. `browser-proof.mjs` drives real review controls and checks192 paired poses; `gameplay-proof.mjs` uses actual movement/attack keys and traverses the arena to see the enemy attack. Both inspect read-only telemetry. Set `KUNAI_URL` for live verification, otherwise they serve `../kunai-eight-final-web` (`KUNAI_DIR` overrides). Evidence goes to ignored build folders.

The16 GIFs are exact paused Godot captures assembled with source hold durations, normal and half speed for each facing. `all-directions-contact.png` compares both skins at the opening contact key. Source clocks in the interactive review expose frame timing without interpolation.
