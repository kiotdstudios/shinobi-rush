# ORCHA — QUEUED: Lightning Clone Substitution Art Prototype (2026-10-19)

**Assigned:** Orcha. **Status:** QUEUED (pending PR merge). **Scope:** PixelLab visual animation prototype only. **Codex owns Chidori.** Do not duplicate Codex's work.

## Source references and mechanic
- Naruto: Ultimate Ninja Storm: timed L2/R2 substitution just before an incoming hit; close-range substitution reappears behind attacker. See https://www.neoseeker.com/naruto-ultimate-ninja-storm/faqs/183345-naruto-uns-a.html
- Fourth Naruto databook *Jin no Sho*, p.304: Lightning Release Shadow Clone dissolves into electrical discharge when destroyed, paralyzing target. Reference https://www.scribd.com/document/685986166/Fourth-Databook-Jutsu-Files-The-Narutoversity
- Naruto to Boruto: Shinobi Striker Lightning Style Shadow Clone substitution: player moves behind attacker and clone shocks/paralyzes target. Reference https://shinobi-striker.fandom.com/wiki/Lightning_Style%3A_Shadow_Clone_Jutsu

## Intended sequence (not a summoning jutsu)
1. Player times **L2** shortly before an incoming melee hit; the player visually remains in place as the decoy.
2. Attacker's weapon connects with apparent player body. Show **one brief false-hit silhouette**—not an idle summoning pose.
3. Thin glowing cracks tear across body; silhouette breaks into **scattered jagged bolts of electricity**, NOT smoke, wood log, or an extra standing ally.
4. Blue-white lightning lashes into attacker; attacker briefly stunned (Aki implements gameplay).
5. **Real player instantly reappears behind attacker**, facing them, ready for a follow-up. No visible running around attacker, no full teleport travel animation.

## Animation language
- Key poses: believable intact decoy; false hit; fractured silhouette; lightning burst; empty aftermath; player rear reveal.
- 1-frame electric smear and strategically skipped in-betweens make the burst violent. Add overshoot, branching arcs, residual sparks, follow-through. Make silhouette readable at approved close-camera zoom.
- Start with **one supported direction**, 128x128 RGBA character-aligned sprite frames; larger independent transparent VFX canvases allowed without changing character scale. Preserve approved existing character identity, palette and foot anchor.
- Separate decoy body break, electric arc burst, stun contact spark and rear-appearance flash where feasible. Aki must be able to spawn/despawn these independently.
- Produce a contact sheet, transparent frame exports, animated preview, frame/event metadata (`substitute_trigger`, `false_hit`, `clone_fracture`, `shock_active`, `rear_reveal`, `counter_ready`) and QA report.

## PixelLab procedure and guardrails
- Read `skills/pixellab-combat-animation/SKILL.md` from this PR and current PixelLab API docs before choosing an endpoint. Use existing approved sprite reference, never a newly invented character.
- Verify authorized credentials without printing secrets; prepare an endpoint/cost/credit estimate and **ask owner before any paid generation**. Stop if credentials, budget or API support are missing. No automatic paid retries.
- First storyboard the full effect. Then generate **one short prototype**, not all directions.
- No gameplay implementation: **Aki** owns L2 mapping, precise hit validation, cooldown/consumption, invulnerability, safe rear spawn, attacker stun and counter window. Coordinate frame-event handoff with Aki.
- No edits to camera, occlusion, Chidori art, movement or combat controller. Follow Orcha reporting and PR rules.

## Proposed gameplay parameters for Aki to evaluate (NOT Orcha art requirements)
- L2 press window around 100–150 ms before eligible incoming melee contact; tune in playtest.
- Successful substitute negates incoming damage, briefly stuns attacker, repositions player to a collision-safe spot behind target and offers an immediate counterattack.
- Failed timing does not trigger the clone effect. Cooldown/charges prevent spamming. Determine projectile behavior separately; don't assume rear teleport always works.

**Done:** one-direction art proof-of-concept with contact sheet, preview, QA, source/cost notes and handoff; owner approval required before bulk generation or paid calls.
