# Issues found during work

Defects noticed and not fixed in the session that found them. One bullet each:
`YYYY-MM-DD · file/command · what is wrong · how it was found`. Delete when fixed.
2026-10-23 · controls-probe.mjs · Bandit vision overlay toggle leaves node count off by one after OFF (nodes=834 instead of the pre-toggle baseline 835); affects vision-button-toggles-on-off and vision-repeat-toggle-stable probe assertions · confirmed present on a clean main export (1e29a39) with no wall-kit-sort-fix changes, so it predates and is unrelated to that fix; found while running the full browser smoke suite for orders/Orcha/2026-10-23-wall-kit-sort-fix.md
