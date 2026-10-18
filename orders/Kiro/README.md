# Kiro — Orders

This is **Kiro's dedicated work-order inbox**. Read [shared rules](../README.md) before starting.

Only take orders explicitly assigned to **Kiro**. Create separate dated Markdown orders here; update their statuses and attach commits/PRs and test evidence.

**Current status:** No new orders assigned by this folder setup.


## Mandatory completion process
Before **any implementation commit**, run relevant tests and playtest changed gameplay, record actual results, and fix failures. After **every job** (including blocked work), write a report in `orders/Kiro/reports/YYYY-MM-DD-task-name-report.md` detailing work done, files changed, pre-commit tests/results, issues, questions, outstanding tasks, and commit/PR link. **Read and follow the full mandatory policy and report template in [shared orders README](../README.md).** Do not mark work DONE without a report and verified tests.


## Start immediately and publish to live testing
When you read a `QUEUED` order assigned to you, **start it immediately without another prompt**. After testing and committing, integrate using the shared PR/branch process and **publish gameplay changes to the live browser test build automatically**. Open the deployed game and verify the change, then record the live build URL/version, result, issues, and questions in your report. See [master execution and deployment policy](../README.md). Do not mark DONE if the live build was not verified (unless deployment is genuinely not applicable).


## Premium roguelike-inspired game vision
**Required reading:** [Shinobi Rush quality and inspiration brief](../../docs/vision/PREMIUM_ACTION_ROGUELIKE_QUALITY_BAR.md). Aim for premium AAA-level polish in combat, animation, VFX, enemy readability and replay appeal. **Do not change the locked persistent RPG progression, world layout, death/save rules, or add permadeath/procedural run resets without owner approval.**


## Mandatory PixelLab API art-generation policy
**All new generated pixel-art assets for Shinobi Rush must be created through the PixelLab API** (characters, directional sprites, animations, equipment, enemies, tiles, props, environment art, UI pixel art and pixel VFX). Read [PixelLab API art pipeline](../../docs/visuals/PIXELLAB_API_ART_PIPELINE.md) before art work. Codex owns generation; other agents request assets from Codex rather than using alternative generators. Manual pixel cleanup, sprite compositing, shaders, particle systems, and programmatic Godot integration are permitted post-processing—not substitutes for PixelLab-generated source art. Never embed or commit API keys. If PixelLab API credentials, features, quotas or outputs are unavailable, report BLOCKED; do not silently switch generators.
