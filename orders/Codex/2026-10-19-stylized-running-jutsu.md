# ORDER — Stylized high-speed running jutsu preview
- Agent: Codex
- Owner: Codex (art)
- Status: REVIEW
- Priority: P1
- Branch/PR: codex/stylized-running-jutsu — https://github.com/kiotdstudios/shinobi-rush/pull/35
- Dependencies: approved128px sprint, no controller dependency

## Objective
Show extraordinary hand-weaving speed while sprinting, blue-white lightning gathering in one hand, and an explosive forward thrust. Favor fighting-game pose contrast and controlled frame omission over literal named hand signs.

## Context / References
Owner revision: Running Hand Signs → Chidori. Approved player appearance, elevated three-quarter camera, production sprint and fixed foot anchor[64,116].

Owner correction: https://qph.cf2.quoracdn.net/main-qimg-926acab88f1d1d30bf811588aceb6683 is an animated GIF, not a still. Downloaded for inspection outside the repository:500×280,12 frames,40ms each,480ms loop. Its charge arm remains extended backward behind the hip with electricity trailing while sprinting. Use that running charge posture. The separately attached still shows a different low-hand pose; it does not override the motion reference. Raised-hand charge was rejected and must be replaced. Preserve character appearance; do not copy the reference character/outfit/background.

## Scope / Files owned
One SE preview with2–3 hand silhouettes,1–2 smear/multiple drawings, charge hold, thrust, impact and running recovery. Preserve continuous approved lower-body sprint motion. Separate sharp lightning VFX. Art/source/metadata, looping preview, labeled contact sheet and review page only. No movement/combat/camera controller or production manifest edits.

## Deliverables
Short loop, labeled contact sheet, transparent128px character frames and independent electrical effect frames, variable timing metadata, source receipts and test report/PR.

## Acceptance Criteria / Tests
No idle poses, stable scale/foot origin, lower-body running throughout, sharp pixel clusters, readable hand silhouettes at close gameplay zoom. No baked shadow/electricity; no generic motion blur. Verify dimensions/alpha/frame order, lower-body source continuity, Godot imports and phone/browser preview. Do not pad animation with needless in-betweens.

## Handoff / Notes
Dedicated isolated art preview, not a runtime combat implementation. Existing modular sword proof PR33 remains separate. New owner request takes priority over broad combat-art expansion pending proof acceptance.

Corrected motion-reference version delivered; see reports/2026-10-19-stylized-running-jutsu-report.md. Final visual acceptance remains with the owner.

Owner requested more dynamic VFX: added longer trailing lightning, gathering sparks, speed ribbons and larger impact; see reports/2026-10-19-running-jutsu-dynamic-vfx-report.md. Same body and timing.
