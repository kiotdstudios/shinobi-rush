# Red-scarf bandit locomotion — Aki handoff

Owner supplied a new masked/topknot/red-scarf bandit design and explicitly prohibited logos. Headband is plain deep-red cloth without a metal emblem plate. Deliver requested idle, regular pumping-arm run and forward-leaning arms-back ninja sprint in S/SE/E/NE/N/NW/W/SW. No new hit/death/attack clips implied by this locomotion request.

Native128×128 RGBA, common foot/root[64,116], target standing body scale104px, no floor shadow/terrain/blur. Actual per-clip frame counts and timings live in bandit_128.art.json. Regular run and sprint are distinct silhouettes, not playback-speed aliases. Source canvases may include generator padding; exports use one fixed translation per clip, never frame-by-frame bounding-box recentering or body scaling.

IMPORTANT: SpriteLibrary currently recursively scans all *.manifest.json under assets/characters and first_valid sorts by id. This delivery intentionally uses *.art.json, preventing bandit from silently becoming the player's default set. Before runtime adoption, bind this set explicitly to BanditVisual and preserve the player's selected production set. Do not simply rename the art JSON on main without checking that selection path.

Current BanditVisual is procedural. Aki owns replacing its draw path, approach/run mapping, any sprint state/AI choice, hit/death fallback, WorldScale compatibility, tint/HP readability, state/camera behavior, runtime tests and live deployment. Keep existing placeholder fallback for requested states not yet drawn. Run can represent current approach locomotion; do not infer a new walk or combat animation from it.

Review all eight facing transitions at close gameplay zoom, stable root/collision footprint, nearest filtering and no mipmaps. Art speed proposals and half-speed inspection are separate from authoritative enemy movement/combat balance. Runtime movement should choose animation timing to avoid foot sliding; this asset PR does not alter velocities.
