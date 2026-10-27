# All-black editor action audit

Runtime: TrainingArena owns PlacedObjects, WorldEditor CanvasLayer and Overlay/GridLayer/VoidSheet. WorldEditor builds Root/BuilderPanel/BuildPage/SettingsPage dynamically. New UI adapts these instances.

| Existing action | New control |
|---|---|
| set_tool/press/paint_to/end_stroke | Tools, tiles and object cards |
| cycle_brush/set_shape/set_terrain/cycle_bank, AutoTile.apply/erase | Tiles brush and Rules terrain/shoreline controls |
| hit_test/select_in_rect/selected_objects/drag_to/group_drag_to | Canvas select/box/multi-select, inspector |
| PlacedObjects.move/_record/_changed | Inspector position commit and orientation ID swap |
| pan_by/_camera, SettingsPanel zoom | Middle/Space drag, wheel and real minimap |
| set_type_filter/set_all_filters | Palette tab/category/search, existing filters preserved |
| undo/redo/can_undo/can_redo | Toolbar and Ctrl+Z/Y |
| save_now/PlacedObjects.save/load_dict/load_saved | Save/Open, same browser storage and JSON |
| _clear_pressed/_reset_pressed | New confirmation and preserved Reset |
| copy_selection/begin_paste/paste_at | Clipboard controls and Ctrl+C/V |
| save_stamp/use_stamp/delete_stamp, StampStore | Rules stamps |
| show_grid/snapped_pos | Grid/Snap toolbar |
| type_visible/type_locked | Grouped layer visibility and genuine edit locks |
| obstacles/ArenaNav, real light instances | Collision/Nav/Lighting overlays |
| MapEditorMode.open_page | Save then Playtest in game tab |
| _adopt_settings_page | Settings, same original controls |
| scan_problems/next_problem/clear_problem_flags | Rules problem scan |
| fill_void/jump_to_next_void/_void_blocks_save | Rules fill/next void, save guard unchanged |
| shared tool/place_id/selection/snap/show_grid | Inspector and status state synchronization |

## Regression checklist

Terrain, grass/ground brush; autotiling/water/shoreline; objects/movement/erase; grouped undo/redo; save/load older layouts; search/filter every catalog ID; clipboard/stamps; spawn/enemy/pickup/shrine; visibility vs filter; lock paint/place/move/delete; no UI bleed; sidebar collapse/minimap; browser persistence/playtest.

## Delivery

1. Black shell with old controls preserved.
2. Asset browser and tools.
3. Inspector and layers.
4. Real minimap, shortcuts and polish.

No schema change: version7 items {id,x,y}; orientation uses supported catalog pairs, not sprite rotation. Existing type_of names retained for tests and filters. New editor groups are separate from Godot rendering layers. No unsupported editable collision or arbitrary rotation.
