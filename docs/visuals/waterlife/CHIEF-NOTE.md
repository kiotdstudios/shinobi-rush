# Chief — rare purple frog and water presentation

Owner requested this Easter egg on October 26, 2026: a purple frog jumps onto a lily pad, notices a fly, snaps out its tongue to try to eat it, and jumps into the water with a splash.

**Rarity is exactly 1 in 1,000,000 per eligible water visit. Never roll every frame, footstep, tile, or particle.** The integer draw is uniform over 0 through 999,999; only zero wins. A visit becomes eligible when the player is on open water with a lily within 240 world pixels. After that roll, ten uninterrupted seconds on dry ground are required before another visit can qualify. This is a visual Easter egg, with no invented reward, combat advantage or progression change. Eligibility currently resets on a fresh game session; do not advertise account-lifetime rarity.

The isolated `?waterlife=review` art scene deliberately forces the frog so the owner can inspect its complete sequence at Normal or Half speed. That preview is separate from gameplay and does not alter the live probability. It is not evidence of a naturally successful random spawn.

Water presentation reads the existing player's water/chakra state and actual reached positions. It changes no chakra costs, movement, combat or camera rules. Dry dust is suppressed over water. Bridge decks remain dry through the existing water predicate.

Six floating plant variants use 72px cells on the existing 72 × 36 diamond grid: single/double/triple pads, white lotus, lilac lotus and lotus bud. They are decorative, non-colliding, gently bobbing objects. Initial runtime population is bounded and deterministic around existing open-water tiles; no authored terrain is overwritten.

Art sources, layer anchors and timing live in `assets/environment/blightwood_waterlife/waterlife.art.json`; normal/half previews and verification evidence live beside this note. Follow the job report for current integration/live status.
