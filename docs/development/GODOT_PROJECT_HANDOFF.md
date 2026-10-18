# Godot project handoff

Written by Kiro for Order 01 ([order](../../orders/Kiro/order_01.md)). It describes the Godot project that now exists at the repository root, what the CI pipeline requires of it, and the checklist for anyone who changes it. Pipeline description: [GODOT_CI_AND_DEPLOYMENT.md](GODOT_CI_AND_DEPLOYMENT.md).

## Why you are reading this

Order 01 was delivered in **two stages**. **Stage 1 (CI and deployment pipeline) is merged** (PR #4). **Stage 2, a separate pull request, adds the minimal real Godot 4.7.2 project at the repository root** (the project owner answered "yes" on 2026-10-17 and reassigned the bootstrap to Kiro, `orders/README.md` rule 4): GL Compatibility, one single-threaded Web export preset named `Web`, main scene `res://scenes/main.tscn`, a training arena with a controllable **placeholder** player (WASD move, Shift sprint, InputMap actions), a debug HUD, an animation lab for judging sprite size and animation, a dependency-free test runner (`tests/run_tests.gd`), a `JavaScriptBridge` readiness hook (`window.__SHINOBI_READY__`) with a small state object (`window.__SHINOBI_STATE__`), and the `.gdignore` markers. How Codex drops art in without code changes: [SPRITE_DROP_IN.md](../prototype/SPRITE_DROP_IN.md); how to test: [TESTING.md](../prototype/TESTING.md).

Order 01 stays IN_PROGRESS ("stage 2 of 2: PR open, first deployment pending") until the first deployment has been verified by the orchestrator. **All art is placeholder.** Nothing here is a gameplay design decision beyond what the prototype brief locks.

The layout is not open: **the repository root IS the Godot project.** The locked architecture in the prototype brief [PLAYER_CHARACTER_CODEX_HANDOFF.md](../prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md) (section 11) lists `project.godot`, `scenes/`, `scripts/` (`scripts/player/`, `scripts/combat/`, `scripts/enemies/`, `scripts/ui/`), `assets/characters/player/placeholder/`, `exports/web/` and `docs/prototype/TESTING.md` side by side. This pipeline adds conventions on top of that brief and does not replace it.

## Checklist

- [x] Godot editor **exactly** <!--pin:GODOT_VERSION-->`4.7.2`<!--/pin-->, stable (the project must not be saved with a newer editor).
- [x] `project.godot` at the **repository root** (the convention; see "Where the project lives").
- [x] A main scene is set and exists; it starts without errors in a browser.
- [x] Renderer: **GL Compatibility** project-wide is recommended (what you test in the browser is then what you ship) but not required. The Web export always uses Compatibility, so another desktop renderer only produces the warning `PRJ005`. Decision for the project owner: see "Desktop renderer" below.
- [x] `export_presets.cfg` is committed with a Web preset named **`Web`**, `variant/thread_support=false`, `variant/extensions_support=false`, no secrets.
- [x] `.godot/` is ignored (the repository `.gitignore` already does this, and also `exports/` and `web/index.*`); `*.uid` and `*.import` files **are** committed.
- [x] An empty `.gdignore` file in each folder of the repository root project that holds no game resources: `docs`, `orders`, `skills`, `world`, `scripts/ci` and `assets/characters/player/references` (committed in stage 2). **Never** put a `.gdignore` in `scripts/` itself, in `assets/` as a whole, or in any other folder that holds game files: it hides the folder from `load()`, `preload()` and the export, and CI rejects it (`PRJ013`).
- [x] Input goes through InputMap actions (keyboard fallback works without a controller).
- [x] Tests: `tests/run_tests.gd` (dependency-free; GUT and gdUnit4 are also detected; see "Tests"); the `window.__SHINOBI_READY__` hook (see "Smoke-test hooks").
- [x] No `push_error()`, `printerr()`, script errors or unhandled JavaScript errors during startup.

## Where the project lives

At the **repository root**, as section 11 of the prototype brief lays it out. The art that Codex delivers to `assets/characters/player/...` has to be inside `res://`, and game code stays in `scripts/<area>/`. CI still discovers `project.godot` at run time (nothing in the pipeline hard-codes a path) and the repository variable `GODOT_PROJECT_DIR` still exists, but only as an escape hatch for a repository that ever holds **more than one** `project.godot`; it is not a second layout. With the project at the root:

- **Discovery and paths.** `discover_project.py` reports `project_dir=.`; every step runs `godot --headless --path <the repository root>`; `build-info.json` records `project_dir: "."`.
- **`.godot/` cache.** Godot's import cache lives in the checkout root. It is git-ignored (`.godot/` in `.gitignore`), never uploaded and never cached by CI, so every run imports from scratch. Commit the `*.uid` and `*.import` files, never `.godot/`.
- **Export output stays outside `res://`.** CI exports to `$RUNNER_TEMP/web-export` and `godot_ci.py export` refuses an output directory inside the project (or the project itself), so nothing generated ever lands in the project tree. Exports you make by hand with the editor go to `exports/web/` (git-ignored).
- **Non-game folders need an empty `.gdignore`.** Godot skips any directory that contains such a file, and a project at the repository root shares its tree with folders that hold no game resources: `docs`, `orders`, `skills`, `world`, `scripts/ci` (CI tooling, with `scripts/ci/smoke/node_modules`) and `assets/characters/player/references` (the approved turnaround must never ship in the game). Without the files Godot imports their images and exports them with the game. Rule `PRJ012` reports, with the exact list, while one is missing (an **error** for `assets/characters/player/references`, a warning for the others). The files are committed: `docs/.gdignore`, `orders/.gdignore`, `world/.gdignore`, `skills/.gdignore`, `scripts/ci/.gdignore`, `exports/.gdignore` and `assets/characters/player/references/.gdignore`. **The `references/` file is the only change under `assets/`**: required (the approved turnaround must never ship), harmless, and not an asset. Codex's art is untouched.
- **Never ignore folders that hold game files.** Do not put a `.gdignore` in `scripts/` or in `assets/` as a whole: on Godot 4.7.2, with `scripts/.gdignore` the import and the resource validation still pass (the folder is simply invisible), the export silently leaves `scripts/player/` out of the pack, and the game dies in the browser with `SCRIPT ERROR: Parse Error: Preload file "res://scripts/player/player_controller.gd" does not exist.` Rule `PRJ013` stops this before any Godot run.
- **The resource walker.** `godot_ci.py validate-resources` loads every `.gd`, `.tscn`, `.scn`, `.tres` and `.res` file. It does not walk a folder that contains a `.gdignore` or its own `project.godot`, any folder whose name starts with a dot (`.git`, `.github`, `.godot`, `.agents`, ...), `node_modules`, the export output folders (`exports`, `build/web`) or `scripts/ci` (also while that folder has no `.gdignore` yet). The walker script is written to a temporary folder outside the project each time, so the repository holds no pipeline GDScript file. The self-test case `repo_shaped_layout` proves all of this against the real engine with a generated project at the root of a checkout, next to non-game folders full of images.

### Desktop renderer (decision for the project owner)

The Godot Web platform renders with Compatibility whatever the project says: the engine registers `rendering/renderer/rendering_method.web = gl_compatibility` as its only allowed value (verified on 4.7.2: a project authored for Forward+ exports and runs in the browser, and the smoke test's engine banner reports Compatibility). The game design is "Windows PC first" with the Web build as a test build, so which renderer the **Windows** build uses is a product decision that CI does not make. Compatibility everywhere is the simplest choice (one renderer to test); Forward+ or Mobile on desktop is allowed, costs only the `PRJ005` warning, and means 2D content must be checked in both renderers. Question for the owner: is Compatibility acceptable for the Windows build?

## Input

Define every control as an InputMap action in `project.godot` (`[input]`), never as hard-coded keys or gamepad ids, with keyboard defaults that work without a controller. The prototype brief ([PLAYER_CHARACTER_CODEX_HANDOFF.md](../prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md), section 3) suggests WASD to move, J light attack, K heavy attack, Space dodge, Shift sprint, F jump, Q substitution and E heal. The action names are the project author's choice; CI does not require specific names. The browser smoke test presses physical keys (`KeyD`, `Space` and `KeyJ` by default, configurable in `scripts/ci/smoke/smoke-config.json`), so keep those keys meaningful or update that file in the same pull request. Godot's built-in `ui_*` actions exist in every project.

## Settings the pipeline checks

`scripts/ci/validate_godot_project.py` runs on every pull request once a project exists (job `Godot CI / build`). Errors fail the gate; warnings are annotations.

| Code | Level | Rule |
| --- | --- | --- |
| `PRJ001` | error | `project.godot` is readable and parseable |
| `PRJ002` | error | `config_version=5` (Godot 4.x) |
| `PRJ003` | error | `application/run/main_scene` is set |
| `PRJ004` | error | the main scene exists. Both `res://...` paths and Godot 4.4+ `uid://...` references are resolved; `uid://<invalid>` (a scene that was never saved with a UID) is rejected |
| `PRJ005` | warning | the desktop `rendering_method` is explicitly not `gl_compatibility` (or `config/features` still lists a Forward Plus / Mobile tag): the Web build is forced to Compatibility, so check 2D content in both renderers |
| `PRJ006` | error | `rendering_method.web`, if present, is `gl_compatibility` (the only renderer the Web platform supports) |
| `PRJ007` | notice | `rendering_method` is not set: desktop uses the engine default (Forward+), the browser uses Compatibility |
| `PRJ008` | error / notice | `config/features` engine version has the pinned major version and is **not newer** than the pinned minor version; older only produces a notice (the engine upgrades the project on import) |
| `PRJ009` | error | not a C#/.NET project (Godot 4 cannot export .NET to Web) |
| `PRJ010` | error / warning | every autoload points to an existing file (`*res://` and `uid://` forms) |
| `PRJ011` | warning | `.gdextension` files are not available in the single-thread, no-extension Web build |
| `PRJ012` | error for `assets/characters/player/references`, warning for the rest | root project: `docs`, `orders`, `skills`, `world`, `scripts/ci` or `assets/characters/player/references` exists without an empty `.gdignore` (the message lists exactly the missing ones) |
| `PRJ013` | error | a `.gdignore` anywhere else (including the project root and `scripts/`) hides `.gd`, `.tscn`, `.tres`, `.scn`, `.res`, `.gdshader` or `.gdextension` files from the import scan, `load()`/`preload()` and the export |
| `PRJ014` | error | `config/name` is "Pipeline Self-Test (not the game)": a generated self-test fixture was committed. It must never be exported or deployed as the game |
| `EXP001` | error | `export_presets.cfg` exists and parses |
| `EXP002`, `EXP003`, `EXP004` | error | exactly one preset has `platform="Web"` and is named `Web` (case-sensitive) |
| `EXP005` | error | `variant/thread_support=false`, **explicitly present**. Threaded exports need cross-origin isolation headers (COOP/COEP) that GitHub Pages cannot send |
| `EXP006` | error | `variant/extensions_support=false`, explicitly present |
| `EXP007` | error | `export_path` is a relative path inside the project ending in `.html` (for example `exports/web/index.html`); no drive letter, no `..` |
| `EXP008` | error / warning | `export_filter` is valid; with `scenes` the main scene is in `export_files`; with `exclude` it is not excluded; `exclude_filter` patterns do not match the main scene |
| `EXP009` | error | no PCK encryption and no committed encryption key |
| `EXP010` | error | no committed secrets (`password`, `token`, `keystore`, ... with a value) anywhere in `export_presets.cfg` |
| `EXP012` | warning | PWA enabled: the service worker can serve stale test builds |
| `EXP013` | error | `for_mobile` texture compression requires `rendering/textures/vram_compression/import_etc2_astc=true` |
| `EXP014` | error / notice | the preset has an options section (is not a placeholder); a custom HTML shell exists |
| `EXP015` | error | no custom export templates (they bypass the pinned, checksum-verified ones) |

Minimum Web preset (what the engine writes for 4.7.2; keep the `variant/...` lines explicit):

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="exports/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=true
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

Create it with Project > Export > Add > Web, switch **Thread Support** off, and save. Do not commit anything under `.godot/` (credentials for other platforms live there, never in `export_presets.cfg`).

## What CI does with the project

On every pull request and every push to `main`, in this order (details: [GODOT_CI_AND_DEPLOYMENT.md](GODOT_CI_AND_DEPLOYMENT.md)):

1. Installs the pinned Godot and the Web export templates (SHA512-verified, cached).
2. `godot --headless --path <project> --import`. Fails on a non-zero exit **or** any `ERROR:` / `SCRIPT ERROR:` line (Godot exits 0 on script parse errors).
3. Static project and preset validation (table above).
4. Loads **every** `.gd`, `.tscn`, `.scn`, `.tres` and `.res` file, except in the folders listed under "Where the project lives" (the ones with a `.gdignore`, dot folders, `node_modules`, export output and `scripts/ci`); that is why `PRJ013` forbids `.gdignore` next to game files. This also catches scripts that no scene references.
5. Runs tests: `res://tests/run_tests.gd` if it exists (see "Tests"), else GUT (`addons/gut`) or gdUnit4 (`addons/gdUnit4`) if present. No framework only produces a warning.
6. Exports Web with the **debug** template, single-threaded, to a temporary folder, and writes `build-info.json`.
7. Opens the export in headless Chromium from a local static server **without** COOP/COEP headers (like Pages): the engine must start, the canvas must be visible and not uniform, and there must be no fatal console, page or network error.
8. On `main` only: deploys to GitHub Pages, then repeats the browser test against the live URL after it serves this commit's `build-info.json`.

The browser test fails on: a page error, `console.error`, any `ERROR:` / `SCRIPT ERROR:` line, WebGL context loss, WebAssembly or pack load failures, HTTP 4xx/5xx, and the Godot "features required to run Godot projects on the Web are missing" notice. `WARNING:` lines and `push_warning()` never fail. `printerr()` and `push_error()` do, because they reach the browser as errors; keep startup clean or fix the cause. A last-resort allowlist exists (`scripts/ci/smoke/console-allowlist.json`) and every entry needs a reviewed justification.

## Smoke-test hooks

- **Readiness hook (used by the game):** when the first playable frame is ready, run `JavaScriptBridge.eval("window.__SHINOBI_READY__ = true;")` (only on `OS.has_feature("web")`). The smoke test then waits for it; without it the test relies on the engine start and a non-blank canvas. If the page defines the hook but it never becomes `true`, the test fails, and `--require-ready-hook` also fails when the hook is absent. All three states are unit-tested, the self-test's `good` case requires the hook, and `smoke-config.json` now sets `require_ready_hook` and `require_input_effect` to `true` for the real game. The game also publishes `window.__SHINOBI_STATE__` (`{frame, x, y, state, sprinting, fps}`, about 10 Hz), which the **controls probe** (`scripts/ci/smoke/controls-probe.mjs`) reads: hold `KeyD` and `x` must grow, hold `Shift+KeyD` and it must be faster with `sprinting=true`, and the player must not pass through a wall. The probe fails with "hooks exist but input had no effect" and skips with a "hooks absent" note only if neither hook is ever defined.
- **Keyboard probe:** `scripts/ci/smoke/smoke-config.json` lists the key sequence (`KeyD:500` means hold D for 500 ms) pressed after startup. It defaults to the keyboard fallback suggested in the prototype brief (WASD, Space, J). The real game sets `"require_input_effect": true`, so the test fails if nothing on screen changes. Gamepad input cannot be automated.
- Custom HTML shell: keep `<canvas id="canvas">` and the `#status` overlay, or set `canvas_selector` in `smoke-config.json`.

## Tests

The `tests` step prefers the project's own dependency-free runner `res://tests/run_tests.gd`, a SceneTree script run with `godot --headless --path . --script res://tests/run_tests.gd`. It prints one `PASS`/`FAIL` line per check and `SUMMARY: N passed, M failed`, and exits non-zero on any failure, which fails the `build` job. Locally it reported `SUMMARY: 123 passed, 0 failed`. GUT and gdUnit4 are still detected if their addons are present; with no framework at all the step exits 0 with a loud warning annotation ("NONE FOUND"). The runner is detected by `detect_test_frameworks()` and `test_command()` in `scripts/ci/godot_ci.py`, covered by a unit test in `scripts/ci/tests/test_export_gate_and_ci.py`. Run `godot --headless --path . --import` once on a fresh clone first (it builds the `class_name` cache).

## Sprite drop-in and the manifest validator

Codex adds art as a sprite set: a `*.manifest.json` plus PNGs under `assets/characters/` (contract: [SPRITE_DROP_IN.md](../prototype/SPRITE_DROP_IN.md)). **Production frames are 128x128 RGBA (locked)**: roughly 100 to 112 px standing height (default 108), consistent foot anchors, overflow canvases of at least 128 in both dimensions with the same body scale. 64x64 art is legacy reference only and must live under `references/`, `previews/`, `source/` or `study/`. The lab can compare any two sets (revisions, overflow canvases). `python scripts/ci/validate_sprite_manifests.py` checks every manifest (schema v1) and prints `::error file=<path>::<message>` annotations; CI runs it in the `detect` job, so manifest errors show up before the engine is involved. `check-export` additionally asserts that the exported `index.pck` contains `project.binary`, every manifest and every sprite PNG import record (`EXPORT011`); `source/`, `references/`, `previews/` and `study/` are excluded from the pack on purpose (add a `.gdignore` to each so Godot does not import them). No sprite set is committed yet, so the check currently asserts 0 manifests.

## Coordination notes for other agents

- **Lab zoom and the camera.** The animation lab's zoom (`Z` / wheel / L-stick click) sets `player.camera.zoom` directly. When Orcha's camera director lands, lab zoom must go through the director, or be disabled while the director is active, so the two never fight over the camera.
- **WebBridge smoke-test contract.** The `__SHINOBI_READY__` and `__SHINOBI_STATE__` WebBridge hooks are the stable contract the smoke tests rely on. Aki's telemetry must not rename or remove them; add new hooks next to them instead.

## What finishes Order 01

Stage 2 is delivered by a pull request (placeholder art only). The order is finished when all of these are true, verified by a person reading the evidence (not by this document):

1. Stage 1 (the pipeline) is merged (done: PR #4), and the stage 2 pull request carries the real `project.godot` with a Web preset named `Web` as above.
2. `Godot CI` passes on the stage 2 pull request (the `godot-ci-gate` check, with `build` and `smoke-predeploy` green).
3. The Pages steps in [GODOT_CI_AND_DEPLOYMENT.md](GODOT_CI_AND_DEPLOYMENT.md#admin-only-steps) hold (Pages and the `github-pages` environment are set up, done on 2026-10-18; the Godot gate is added to the required status checks by an administrator once the first `main` run has proven it).
4. A push to `main` deployed: `deploy` and `smoke-postdeploy` are green and the post-deploy artifact holds `deploy-info.json` with the real `page_url` and a matching commit SHA.
5. Someone opens that URL in a browser and confirms the game starts.
6. `orders/Kiro/order_01.md` acceptance boxes are ticked with links to the runs, the job report is updated with the URL and build ID, and the report's URL/build evidence box is ticked last. The orchestrator sets the final status.

Until then the order stays IN_PROGRESS ("stage 2 of 2: PR open, first deployment pending"), live deployment is PENDING and no URL is claimed as verified.
