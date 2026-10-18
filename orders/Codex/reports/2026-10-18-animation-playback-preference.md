# Owner animation playback preference
- Agent: Codex
- Date: 2026-10-18
- Related order: Order 01
- Status: preference recorded; full art production remains incomplete

The owner prefers the south-east breathing at half-speed and finds the 1x preview
too fast. Default future review playback is now 0.5x. Idle playback is 0.5x:
a 24fps source timeline plays at 12 ticks/sec, giving a 16-tick breath of 1.333 sec.
South-west's 8 unique poses retain their two-tick holds (effective 6 poses/sec).
No source character pixels were redrawn or discarded for this timing change.

Other states start review at 0.5x and receive explicit per-action playback tuning.
Attack/dodge/movement timing and gameplay control responsiveness must be authored
and verified with their gameplay owner; this feedback does not silently lock a
global engine time-scale change.

Delivery: idle-current.gif is a byte-for-byte alias of the previously tested
idle-v2-half-speed.gif. Normal/half/quarter comparison files remain available.
Validation before commit: verify alias equality, GIF frame count and 1330ms loop
(the format rounds nominal 1333ms), preference JSON and repository checks.
No live game deployment applies to this review-default/documentation update.
