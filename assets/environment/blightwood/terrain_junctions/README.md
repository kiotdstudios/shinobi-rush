# Blightwood missing pairs and junction kit

See `junctions.art.json` and `docs/visuals/terrain-junctions/AKI_HANDOFF.md`.
Regenerate with `scripts/art/build_junction_kit.py`, then `scripts/art/reproduce_pr245_junctions.py`.
Six reusable RGB occupancy patterns, two pair families (88 tiles), ten complete three-material families (360 native exports). Exact approved source pixels, 72×36 diamond, (36,18) anchor. No new raw generated art or modified source textures.
Static terrain: no animation timing. No collision. Builder registration is manual; automatic placement remains Aki's integration.
