# Godot project handoff

Written by Kiro for Order 01 ([order](../../orders/Kiro/order_01.md)). It lists exactly what the repository needs so that the Godot CI pipeline starts working the moment the project lands, and it is the checklist for whoever creates that project. Pipeline description: [GODOT_CI_AND_DEPLOYMENT.md](GODOT_CI_AND_DEPLOYMENT.md).

## Why you are reading this

Order 01 is delivered in **two stages**. **Stage 1, the CI and deployment pipeline, is delivered by the pull request that contains this document; the order is IN_PROGRESS, not finished.** **Stage 2 is a separate follow-up pull request, opened after stage 1 is merged: a minimal real Godot project at the repository root plus the first live deployment.** The project owner answered "yes" to building that minimal real project on 2026-10-17 and reassigned the bootstrap to Kiro (`orders/README.md`, rule 4), so it is no longer an unowned dependency.

Until stage 2 lands, **no Godot project exists in this repository** (no `project.godot`, `.tscn`, `.gd` or `export_presets.cfg` on any branch). The pipeline is built and self-tested against throwaway projects that exist only in a temporary folder while the tests run, but it has never run on the game. It will run automatically, with no further changes, as soon as a real `project.godot` is merged. **Do not add a placeholder project to stage 1 just to turn the checks green.** The order forbids deploying a fake placeholder as the game, and stage 1 commits no Godot project, scene, GDScript file or `.gdignore`.

The layout is not open: **the repository root IS the Godot project.** The locked architecture in the prototype brief [PLAYER_CHARACTER_CODEX_HANDOFF.md](../prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md) (section 11) lists `project.godot`, `scenes/`, `scripts/` (`scripts/player/`, `scripts/combat/`, `scripts/enemies/`, `scripts/ui/`), `assets/characters/player/placeholder/`, `exports/web/` and `docs/prototype/TESTING.md` side by side. This pipeline adds conventions on top of that brief and does not replace it.

## Checklist

- [ ] Godot editor **exactly** <!--pin:GODOT_VERSION-->`4.7.2`<!--/pin-->, stable (the project must not be saved with a newer editor).
- [ ] `project.godot` at the **repository root** (the convention; see "Where the project lives").
- [ ] A main scene is set and exists; it starts without errors in a browser.
- [ ] Renderer: **GL Compatibility** project-wide is recommended (what you test in the browser is then what you ship) but not required. The Web export always uses Compatibility, so another desktop renderer only produces the warning `PRJ005`. Decision for the project owner: see "Desktop renderer" below.
- [ ] `export_presets.cfg` is committed with a Web preset named **`Web`**, `variant/thread_support=false`, `variant/extensions_support=false`, no secrets.
- [ ] `.godot/` is ignored (the repository `.gitignore` already does this, and also `exports/` and `web/index.*`); `*.uid` and `*.import` files **are** committed.
- [ ] An empty `.gdignore` file in each folder of the repository root project that holds no game resources: `docs`, `orders`, `skills`, `world`, `scripts/ci` and `assets/characters/player/references` (stage 2 adds them; stage 1 commits none). **Never** put a `.gdignore` in `scripts/` itself, in `assets/` as a whole, or in any other folder that holds game files: it hides the folder from `load()`, `preload()` and the export, and CI rejects it (`PRJ013`).
- [ ] Input goes through InputMap actions (keyboard fallback works without a controller).
- [ ] Optional but recommended: tests under `tests/` (GUT or gdUnit4 are detected today; see "Tests" for a dependency-free runner); the `window.__SHINOBI_READY__` hook.
- [ ] No `push_error()`, `printerr()`, script errors or unhandled JavaScript errors during startup.

## Where the project lives

At the **repository root**, as section 11 of the prototype brief lays it out. The art that Codex delivers to `assets/characters/player/...` has to be inside `res://`, and game code stays in `scripts/<area>/`. CI still discovers `project.godot` at run time (nothing in the pipeline hard-codes a path) and the repository variable `GODOT_PROJECT_DIR` still exists, but only as an escape hatch for a repository that ever holds **more than one** `project.godot`; it is not a second layout. With the project at the root:

- **Discovery and paths.** `discover_project.py` reports `project_dir=.`; every step runs `godot --headless --path <the repository root>`; `build-info.json` records `project_dir: "."`.
- **`.godot/` cache.** Godot's import cache lives in the checkout root. It is git-ignored (`.godot/` in `.gitignore`), never uploaded and never cached by CI, so every run imports from scratch. Commit the `*.uid` and `*.import` files, never `.godot/`.
- **Export output stays outside `res://`.** CI exports to `$RUNNER_TEMP/web-export` and `godot_ci.py export` refuses an output directory inside the project (or the project itself), so nothing generated ever lands in the project tree. Exports you make by hand with the editor go to `exports/web/` (git-ignored).
- **Non-game folders need an empty `.gdignore`.** Godot skips any directory that contains such a file, and a project at the repository root shares its tree with folders that hold no game resources: `docs`, `orders`, `skills`, `world`, `scripts/ci` (CI tooling, with `scripts/ci/smoke/node_modules`) and `assets/characters/player/references` (the approved turnaround must never ship in the game). Without the files Godot imports their images and exports them with the game. Rule `PRJ012` warns, with the exact list, while one is missing. **Stage 2 adds these files; stage 1 commits none, on purpose.**
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
| `PRJ012` | warning | root project: `docs`, `orders`, `skills`, `world`, `scripts/ci` or `assets/characters/player/references` exists without an empty `.gdignore` (the message lists exactly the missing ones) |
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
5. Runs tests if GUT (`addons/gut`) or gdUnit4 (`addons/gdUnit4`) is present. GUT: `tests/` or `test/` (or `.gutconfig.json`). No framework only produces a warning (see "Tests").
6. Exports Web with the **debug** template, single-threaded, to a temporary folder, and writes `build-info.json`.
7. Opens the export in headless Chromium from a local static server **without** COOP/COEP headers (like Pages): the engine must start, the canvas must be visible and not uniform, and there must be no fatal console, page or network error.
8. On `main` only: deploys to GitHub Pages, then repeats the browser test against the live URL after it serves this commit's `build-info.json`.

The browser test fails on: a page error, `console.error`, any `ERROR:` / `SCRIPT ERROR:` line, WebGL context loss, WebAssembly or pack load failures, HTTP 4xx/5xx, and the Godot "features required to run Godot projects on the Web are missing" notice. `WARNING:` lines and `push_warning()` never fail. `printerr()` and `push_error()` do, because they reach the browser as errors; keep startup clean or fix the cause. A last-resort allowlist exists (`scripts/ci/smoke/console-allowlist.json`) and every entry needs a reviewed justification.

## Smoke-test hooks you can add (optional)

- **Readiness hook (recommended; stage 2 will use it):** when the first playable frame is ready, run `JavaScriptBridge.eval("window.__SHINOBI_READY__ = true;")` (only on `OS.has_feature("web")`). The smoke test then waits for it; without it the test relies on the engine start and a non-blank canvas. If the page defines the hook but it never becomes `true`, the test fails, and `--require-ready-hook` also fails when the hook is absent. All three states are unit-tested, and the self-test's `good` case requires the hook.
- **Keyboard probe:** `scripts/ci/smoke/smoke-config.json` lists the key sequence (`KeyD:500` means hold D for 500 ms) pressed after startup. It defaults to the keyboard fallback suggested in the prototype brief (WASD, Space, J). The test warns if nothing on screen changes; set `"require_input_effect": true` when the first scene is reliably interactive. Gamepad input cannot be automated.
- Custom HTML shell: keep `<canvas id="canvas">` and the `#status` overlay, or set `canvas_selector` in `smoke-config.json`.

## Tests

The `tests` step runs GUT or gdUnit4 when the addon is present; otherwise it exits 0 with a loud warning annotation ("No GDScript test framework found ... NOT unit-tested") and a "NONE FOUND" job summary. Stage 2 may add a dependency-free convention: `res://tests/run_tests.gd`, a SceneTree script run with `godot --headless --path . --script res://tests/run_tests.gd` that exits non-zero on failure. The extension point is small: one more branch in `detect_test_frameworks()` and `test_command()` in `scripts/ci/godot_ci.py` plus a unit test in `scripts/ci/tests/test_export_gate_and_ci.py`. Stage 1 does not implement it, because no such runner exists yet.

## Stage 2 and what finishes Order 01

Planned scope of **stage 2** (not delivered; nothing below exists yet): a minimal real Godot 4.7.x project at the repository root with the GL Compatibility renderer, one single-threaded Web export preset named `Web`, the main scene `res://scenes/main.tscn`, an arena with a controllable placeholder player (movement and sprint through InputMap actions) and a debug HUD, a dependency-free headless test runner, a `JavaScriptBridge` readiness hook (`window.__SHINOBI_READY__`) plus a small state object that the browser smoke test can read to prove input works, and the `.gdignore` files listed above. GitHub Pages is already enabled (Actions source; 2026-10-18, by the orchestrator with the owner's authorization), so the first push to `main` after the stage 2 merge can deploy.

The order is finished when all of these are true, verified by a person reading the evidence (not by this document):

1. Stage 1 (this pipeline) is merged by the project owner, and a real `project.godot` follows in the stage 2 pull request, with a Web preset named `Web` as above.
2. `Godot CI` passes on the stage 2 pull request (the `godot-ci-gate` check, with `build` and `smoke-predeploy` green).
3. The Pages steps in [GODOT_CI_AND_DEPLOYMENT.md](GODOT_CI_AND_DEPLOYMENT.md#admin-only-steps) hold (Pages and the `github-pages` environment are set up; the new Godot check(s) are added to the required status checks by an administrator once stage 2 has proven them).
4. A push to `main` deployed: `deploy` and `smoke-postdeploy` are green and the post-deploy artifact holds `deploy-info.json` with the real `page_url` and a matching commit SHA.
5. Someone opens that URL in a browser and confirms the game starts.
6. `orders/Kiro/order_01.md` acceptance boxes are ticked with links to the runs, the job report is updated with the URL and build ID, and the report's URL/build evidence box is ticked last.

Until then the order stays IN_PROGRESS ("stage 1 of 2 delivered"), live deployment is NOT PERFORMED and no URL is claimed.
