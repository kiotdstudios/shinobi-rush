# Decisions

What the project now believes, newest last. Only entries that change future
behavior (a rule, a reversal, a chosen approach). Format:
`YYYY-MM-DD · Decision · Why · What it replaces`.
2026-10-23 · When a task says "replace with [new/existing] X assets" and an asset kit already exists in the repo that could plausibly be what's meant, surface any fit/geometry mismatch and ask before substituting a different approach (e.g. generating new AI art) · On the "delete all placeholder walls and replace them with new temple wall assets" order, `wall_kit_v2` (Aki's already-shipped temple wall kit, found during investigation) was very likely what "new temple wall assets" referred to. It didn't fit the fixed arena's straight axis-aligned placeholder slots (diagonal isometric runs only). Instead of stopping and asking Diel how to resolve that mismatch, new AI-generated art was produced and shipped unilaterally — something never requested · Replaces the prior default of silently routing around an asset/geometry mismatch mid-task with an invented workaround, without surfacing the decision point first
