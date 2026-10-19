# Player128 animation handoff
Runtime manifest: ../player_128.manifest.json (schema1, id player_128).
Includes actual128x128 transparent RGBA PNGs: idle v5, walk v1, owner-approved run v3, sprint v5 for gameplay testing. No review GIFs used as runtime art. Eight unique directions; no mirroring. Origin[64,116], standing body104px, fixed anatomical scale. All original pose bytes preserved. No baked ground shadows.

Playback defaults12poses/sec per owner half-speed preference; authored timeline24fps retained as metadata. Idle16timeline ticks/direction (SW8unique poses held2ticks each, represented by repeated references to the same PNGs); walk16; run20; sprint20 except NW11 purposeful poses. Runtime must respect per-direction array length. Sprint source timing is intentionally not padded. Shadow belongs to gameplay rendering, not these assets; owner requests no shadow on animations.

Use existing manifest loader and animation IDs idle/walk/run/sprint. Sprint remains test status for controller speed and transitions. Collision footprint stays at the fixed root, independent of animated limbs. Check run-to-sprint transitions and zoom in the lab before gameplay acceptance. Jump and dodge revisions remain review work and are intentionally absent from this runtime set.

Approved run v3 is delivered; south cadence v4 candidate is preserved locally for further review. Raw AI sources/rejected attempts are omitted from runtime exports. Hash provenance is in production-provenance.json. Order01 is incomplete.
