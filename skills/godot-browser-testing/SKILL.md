---
name: godot-browser-testing
description: Test Godot 4 gameplay, input, art integration, and Web exports before committing and after live deployment.
---
# Godot browser gameplay testing

1. Identify the actual Godot project root, engine version, configured Web export preset, deployment pipeline, and public test URL. Never invent them.
2. Run available Godot headless import/project validation, scene/script checks, unit tests, and Web export checks using the version configured by the repo. Record exact commands and outputs.
3. Playtest changed systems locally with keyboard and supported controller; for combat test dodge windows, sprint versus run, directional movement, animation transitions, attack/jutsu input, collisions, and UI.
4. Test Web build in a real browser, check console errors, missing assets, broken input, page reload, and gameplay responsiveness. Note platform-specific limitations rather than claiming all browsers work.
5. Capture reproducible test steps and evidence. Fix failures and rerun before committing. After merge/deploy, repeat a smoke test on the actual live URL.
6. If required tools/browser access or deployment config are missing, report BLOCKED with specifics. Never claim a successful test or deployment without executing it.
