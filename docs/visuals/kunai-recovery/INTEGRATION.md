# Recoverable kunai

Uses the existing approved `assets/weapons/kunai/black_kunai.png`. No character redesign, new bitmap generation, or PixelLab credit spend. Motion is rigid Sprite2D translation/rotation with nearest filtering; white light/glints are separate draws. Metallic clinks are synthesized locally.

## Outcomes
- Player or Bandit kunai hitting a character: existing damage/hit reaction, projectile consumed, **no recovery/pickup**.
- Wall/tree collision: blade embeds for 0.4 seconds, falls for 0.30 seconds, then two decreasing bounces over 0.48 seconds. Recoverable only if a nearby player-sized footprint is clear and navigation reaches it from the player. Search stays on the impact side (32–96 world px); no teleporting through surfaces. Inaccessible impacts leave no pickup.
- Range miss: range is clamped without overshoot; fall, tumble, two metal clinks, settle into a small grounded white-glow pickup.
- Bandit blade evaded by dodge/jump/substitution: existing evade decision remains; blade passes the target once, continues, and can recover after its eventual miss/surface hit.

## Pickups / inventory
Map Editor → Pickups → **Kunai (white glow)** creates the same floating collectible/absorption effect as gourds and paper tags, with normal authored-pickup respawn. Throw-created pickups remain grounded, refund exactly one kunai once, and **never respawn**. A full inventory leaves them available. Hidden/frozen editor players cannot auto-collect placed loot. Collection transfers to the existing kunai inventory/D-pad slot; assignments are preserved.

Kunai capacity is 10, matching the existing starter quantity. Previously the generic cap of 9 meant the first thrown starter kunai could not be recovered. Other items retain their cap of 9. At most 64 spent-blade pickups persist in the loaded world; creating another removes the oldest to bound repeated Bandit misses. Authored pickups are exempt.

## Ownership / verification
Direct owner request authorizes the small projectile/pickup changes; no attack, AI state-machine, movement, camera or map redesign. Both projectile owners share the recovery class. Sweep ordering respects the nearest surface before a character behind it. Pickup collection guards reject duplicate or full-bag calls before hiding anything.

Review: `?kunai=recovery` (native `--kunai-recovery`). Real player/Bandit projectile classes, character-hit / miss / surface / Bandit-miss buttons; normal, half speed, pause and collection. Proxy rectangle is only a review collider; game wall/tree art is unchanged. Tests live in `tests/test_kunai_recovery.gd`; repeat browser proof with `node docs/visuals/kunai-recovery/browser-proof.mjs <export-directory-or-public-base-url> <evidence-directory>`.
