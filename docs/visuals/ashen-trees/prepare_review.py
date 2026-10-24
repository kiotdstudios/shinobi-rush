"""Prepare a small isolated Godot Web art review without touching game startup."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT.parent / 'ashen-trees-review-20261024'
assert not DEST.exists(), f'Refusing to overwrite {DEST}'
DEST.mkdir()
files = [
    'scripts/environment/ashen_tree.gd', 'scripts/environment/ashen_wind.gdshader',
    'scripts/art/ashen_trees_review.gd', 'scenes/art/ashen_trees_review.tscn',
    'assets/environment/ashen_trees/ashen-trees.art.json',
    'assets/vfx/ashen_foliage/ash_tumble.png',
    'assets/environment/kosen_courtyard/floor_tiles/floor9_center.png',
    'assets/environment/blossom_trees/textures/tree_01_tiered.png',
    'assets/characters/player/sprites/production/idle/S_000.png',
]
files += [p.relative_to(ROOT).as_posix() for p in (ROOT/'assets/environment/ashen_trees/textures').glob('*.png')]
for file in files:
    target = DEST/file
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/file,target)
(DEST/'project.godot').write_text('''config_version=5
[application]
config/name="Ashen Trees Art Review"
run/main_scene="res://scenes/art/ashen_trees_review.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
environment/defaults/default_clear_color=Color(0.09,0.13,0.17,1)
''')
shutil.copy2(ROOT/'export_presets.cfg',DEST/'export_presets.cfg')
print(DEST)
