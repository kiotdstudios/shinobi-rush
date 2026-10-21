# Bandit art source / reproduction

PixelLab generated the eight-view 128px bandit using the owner's Photo 1 appearance reference and approved player style character `2b5a8809-cf01-46a4-8e85-0602dda701a2`. Character `cc675e30-2723-4145-b03f-c0d245294305`. The plain red cloth headband intentionally excludes the reference's emblem/metal plate.

Final animation groups: idle `038d319d-66b8-43a9-a2e5-5e13cc0eba80`, run `e491cd61-d8ae-4b68-ae4e-71c2d5ec4b65`, sprint `60917857-d5b0-4d16-8841-158e1bcf6f30`. Idle uses breathing-idle; south run uses running-8-frames; other runs use v3 custom full-cycle generation after template batches changed costume details/direction. Sprint uses PixMiniMax after v3 failed the arms-back pose. Northwest sprint received an additional pose revision. Final server URLs and source types are recorded in character-status.txt; initial receipts are in pixellab-jobs.json. No credentials or reference base64 are included.

`character.zip` is a locally assembled archive of the exact final server PNGs and an export-compatible index (not a claimed unmodified bulk API archive). Bulk download was locked while jobs ran. Individual downloads use curl because urllib received HTTP 403; curl retries transient TLS/network failures. `raw/` retains the 160 chosen motion images at their actual generated sizes. Some source canvases contain padding; no body is resized.

Run from repository root:

```powershell
python assets/characters/bandit/source/download_ready.py  # optional network refresh from saved URLs
python assets/characters/bandit/source/export.py
python assets/characters/bandit/source/previews.py
python assets/characters/bandit/source/validate.py
```

Export uses one fixed translation for each direction/clip. Southeast run has a documented +2px vertical correction across its entire clip for clear headroom. No per-frame bounding-box recentering, interpolation or fabricated motion. PixMiniMax southeast's neutral reference frame is omitted from the loop; its eight motion frames are preserved. Other clips already omit their reference at generation.

Native 128px RGBA, shared root [64,116], no floor shadows. Idle: four frames, authored 8 FPS, proposed playback 4 FPS. Run/sprint: eight frames each, authored 24 FPS, proposed playback 12 FPS. Review defaults to half speed. Game-close preview is approximately the current 720px viewport close camera (104px body at zoom 1.21); it is an art preview, not a live enemy deployment.

Godot validation: import via scripts/ci/godot_ci.py, then `godot --headless --path . --script assets/characters/bandit/source/validate_bandit.gd`. Browser test: serve repository root on 127.0.0.1:8788 and run browser_check.mjs with the documented local Playwright installation. Source and preview folders are excluded from Godot import; production PNG import sidecars are versioned.
