# Blue chakra charge

Default: blue, half speed. Open `?chakra=review` for touch-friendly playback, all eight headings, pause/step, separate flame/spiral/ground controls and five color samples. In the normal game hold **R** while idle for a visual preview; movement cancels it. This art hook does not consume or regenerate chakra and does not grant transformation upgrades.

The reference GIF was found in the owner's relocated Dropbox folder and studied for its braced stance and upward blue energy. It is not included. The approved player remains unmasked, with olive vest, dark clothing and white wraps. No weapons or floor shadow are baked into the body.

| Layer | Authored frames | Native canvas | Rate | Anchor |
| --- | ---: | --- | --- | --- |
| Body, each heading | 8 | 128×128 RGBA | 12 fps authored, 6 fps default | (64,116) |
| Rear flame mantle | 48 | 256×256 RGBA | 24 fps authored, 12 fps default | (128,230) |
| Front rising spirals | 32 | 256×256 RGBA | 24 fps authored, 12 fps default | (128,230) |
| Ground energy | 16 | 256×256 RGBA | 24 fps authored, 12 fps default | (128,128) |

These are 96 unique VFX drawings across three independent layers, not 96 body drawings or a 96-frame flame sheet. Their combined loop has 96 phases: four seconds at normal speed, eight seconds at default half speed. Five body headings are original generated sets; W/NW/SW mirror E/NE/SE about x64. Every heading has eight unique aligned frames. Only eight stable keys from each generated 16-pose body sheet were retained to prevent excessive size drift. No interpolated frames or padded duplicates.

## Integration

`ChakraChargeVisual` is a separate, nearest-filtered art component. Add it beneath an actor, assign `direction` using `SpriteSet.DIRS8`, call `set_charging(bool)` and `set_chakra_color(Color)`. Its body is separate from the three shader-tinted effects. A unique shader material per layer per instance prevents one player's color changing another's. The shader preserves white highlights; the character texture is never tinted by the chakra palette. All layers stay on the actor's Y-sort plane; child ordering is ground → rear aura → body → front wisps.

The normal-game gate only swaps the visible body while idle and healthy. It does not alter movement/combat controllers, balance, camera or progression. It suppresses this preview while the builder or animation lab is open. Gameplay owners can replace the temporary R preview with their charge action and upgrade colors using the same API.

## Reproduction and evidence

Raw imagegen sheets are preserved in each asset pack's `source/` folder and excluded from Godot with `.gdignore`. `provenance.json` records their tool receipt IDs and SHA256 hashes. `export_chakra.py` performs chroma cleanup, gutter registration, nearest scaling and fixed-anchor exports only. Body scale is shared across all frames. FX uses one shared scale; ground uses one shared Y projection correction. It verifies uniqueness, binary alpha, fixed soles and clear FX margins. It can use committed source sheets when the original generation directory is unavailable.

Run from repository root:

```powershell
python docs/visuals/chakra-charge/export_chakra.py
node docs/visuals/chakra-charge/browser-proof.mjs ../chakra-review-web build/chakra-browser --capture
python docs/visuals/chakra-charge/export_previews.py build/chakra-browser
```

`half-speed.gif` and `normal-speed.gif` assemble all 96 actual browser-rendered phases. `loop-contact.png` samples every fourth phase; `directions-contact.png` compares native body headings with the approved idle sprites. `review.png` and `in-game.png` show the actual engine output. Full proof results and Godot logs are summarized in the Codex job report.
