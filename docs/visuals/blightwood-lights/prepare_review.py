from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[3]
DEST=ROOT.parent/'blightwood-lights-review-20261024'
assert not DEST.exists(),f'Refusing overwrite {DEST}'
DEST.mkdir()
files=['scripts/environment/blightwood_light.gd','scripts/environment/forest_fireflies.gd','scripts/environment/fire_pillar.gd',
       'scripts/art/blightwood_lights_review.gd','scenes/art/blightwood_lights_review.tscn',
       'assets/environment/blightwood_lights/blightwood-lights.art.json',
       'assets/environment/kosen_courtyard/floor_tiles/floor9_center.png','assets/environment/kosen_courtyard/grass/tiles/grass9_center.png']
for folder in ['assets/environment/blightwood_lights/props','assets/vfx/blightwood_lights','assets/audio/ashen_fire']:
    files.extend(p.relative_to(ROOT).as_posix() for p in (ROOT/folder).iterdir() if p.suffix in ['.png','.wav'])
for file in files:
    target=DEST/file;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/file,target)
(DEST/'project.godot').write_text('''config_version=5
[application]
config/name="Blightwood Lights Review"
run/main_scene="res://scenes/art/blightwood_lights_review.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
shutil.copy2(ROOT/'export_presets.cfg',DEST/'export_presets.cfg')
print(DEST)
