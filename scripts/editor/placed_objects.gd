class_name PlacedObjects
extends Node
## The player-editable layer of the arena: trees, walls and decorative grass.
## Solid props block player/bandit navigation; grass is passable. Layouts survive restarts.
## To add a new buildable thing, add ONE row to CATALOG (and an id to CATEGORIES so it shows in the panel).
##   kind "block": a placeholder box (TrainingArena.Block/BlockRear) with `footprint` (w, depth) and `height`.
##   kind "wall":  a pre-drawn isometric wall piece from wall_kit_v2 (art, size, anchor = pixel of the front-bottom-left ground corner, col = ground vector of its collider).
##                 `pos` is that ground corner, snapped to a floor-diamond vertex, so a piece placed at the previous piece's pos + run joins it.
const SAVE_PATH := "user://world_builder_layout.json"
## Repo-tracked layout published via WorldEditor.publish_to_github() (owner 2026-10-23: desktop/editor
## only, never read or written from a Web export). A fresh boot with no per-machine user:// save yet
## falls back to this committed file instead of only the hand-authored defaults, so a layout Diel
## publishes from his own machine shows up for every player once the site redeploys. Never used to
## overwrite an existing user:// save -- that would silently discard a player's own local edits.
const DEFAULT_LAYOUT_PATH := "res://data/world_layout.json"
## v4 adds editable grass to v3 saves, which list EVERY solid object (starting trees and the arena's placeholder walls included, ids "base_N" = WorldScale.BLOCKS[N]).
## v1 saves only listed additions (so they also get the default trees + walls); v2 saves lacked the walls.
const SAVE_VERSION := 7
const CATALOG := {
	"shore_grass_00": {"label": "Water fill", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 0},
	"shore_grass_01": {"label": "Outer Bottom", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 1},
	"shore_grass_02": {"label": "Outer Left", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 2},
	"shore_grass_03": {"label": "Bank SW", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 3},
	"shore_grass_04": {"label": "Outer Right", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 4},
	"shore_grass_05": {"label": "Bank SE", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 5},
	"shore_grass_06": {"label": "Split L/R", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 6},
	"shore_grass_07": {"label": "Inner Top", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 7},
	"shore_grass_08": {"label": "Outer Top", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 8},
	"shore_grass_09": {"label": "Split T/B", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 9},
	"shore_grass_10": {"label": "Bank NW", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 10},
	"shore_grass_11": {"label": "Inner Right", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 11},
	"shore_grass_12": {"label": "Bank NE", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 12},
	"shore_grass_13": {"label": "Inner Left", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 13},
	"shore_grass_14": {"label": "Inner Bottom", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 14},
	"shore_grass_15": {"label": "Land fill", "kind": "ground", "group": "Grass banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "grass", "shore_mask": 15},
	"shore_dirt_00": {"label": "Water fill", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 0},
	"shore_dirt_01": {"label": "Outer Bottom", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 1},
	"shore_dirt_02": {"label": "Outer Left", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 2},
	"shore_dirt_03": {"label": "Bank SW", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 3},
	"shore_dirt_04": {"label": "Outer Right", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 4},
	"shore_dirt_05": {"label": "Bank SE", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 5},
	"shore_dirt_06": {"label": "Split L/R", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 6},
	"shore_dirt_07": {"label": "Inner Top", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 7},
	"shore_dirt_08": {"label": "Outer Top", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 8},
	"shore_dirt_09": {"label": "Split T/B", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 9},
	"shore_dirt_10": {"label": "Bank NW", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 10},
	"shore_dirt_11": {"label": "Inner Right", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 11},
	"shore_dirt_12": {"label": "Bank NE", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 12},
	"shore_dirt_13": {"label": "Inner Left", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 13},
	"shore_dirt_14": {"label": "Inner Bottom", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 14},
	"shore_dirt_15": {"label": "Land fill", "kind": "ground", "group": "Dirt banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "dirt", "shore_mask": 15},
	"shore_rock_00": {"label": "Water fill", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 0},
	"shore_rock_01": {"label": "Outer Bottom", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 1},
	"shore_rock_02": {"label": "Outer Left", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 2},
	"shore_rock_03": {"label": "Bank SW", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 3},
	"shore_rock_04": {"label": "Outer Right", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 4},
	"shore_rock_05": {"label": "Bank SE", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 5},
	"shore_rock_06": {"label": "Split L/R", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 6},
	"shore_rock_07": {"label": "Inner Top", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 7},
	"shore_rock_08": {"label": "Outer Top", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 8},
	"shore_rock_09": {"label": "Split T/B", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 9},
	"shore_rock_10": {"label": "Bank NW", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 10},
	"shore_rock_11": {"label": "Inner Right", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 11},
	"shore_rock_12": {"label": "Bank NE", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 12},
	"shore_rock_13": {"label": "Inner Left", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 13},
	"shore_rock_14": {"label": "Inner Bottom", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 14},
	"shore_rock_15": {"label": "Land fill", "kind": "ground", "group": "Rocky banks", "dir": "res://assets/environment/blightwood_shorelines/tiles/", "water_role": "center", "shore_family": "rock", "shore_mask": 15},

	"water9_corner_top": {"label": "Water Corner Top", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "corner_top"},
	"water9_edge_ne": {"label": "Water Edge Ne", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "edge_ne"},
	"water9_corner_right": {"label": "Water Corner Right", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "corner_right"},
	"water9_edge_nw": {"label": "Water Edge Nw", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "edge_nw"},
	"water9_center": {"label": "Water Center", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "center"},
	"water9_edge_se": {"label": "Water Edge Se", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "edge_se"},
	"water9_corner_left": {"label": "Water Corner Left", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "corner_left"},
	"water9_edge_sw": {"label": "Water Edge Sw", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "edge_sw"},
	"water9_corner_bottom": {"label": "Water Corner Bottom", "kind": "ground", "group": "River water", "dir": "res://assets/environment/blightwood_water/tiles/", "water_role": "corner_bottom"},
	"waterfall_small": {"label": "Small Waterfall", "kind": "water_fx", "footprint": Vector2(80, 32)},

	"blight_wooden_post": {"label": "Wooden Lantern", "kind": "blight_light", "light": 0, "footprint": Vector2(54, 30)},
	"blight_stone_pagoda": {"label": "Pagoda Lantern", "kind": "blight_light", "light": 1, "footprint": Vector2(84, 42)},
	"blight_branch_lantern": {"label": "Branch Lantern", "kind": "blight_light", "light": 2, "footprint": Vector2(70, 38)},
	"blight_stone_brazier": {"label": "Spirit Brazier", "kind": "blight_light", "light": 3, "footprint": Vector2(96, 46)},
	"blight_spirit_totem": {"label": "Spirit Totem", "kind": "blight_light", "light": 4, "footprint": Vector2(75, 40)},
	"blight_fireflies": {"label": "Forest Fireflies", "kind": "fireflies", "footprint": Vector2(32, 16)},

	"fire_tall_pillar": {"label": "Tall Pillar", "kind": "ashen_fire", "fire": 0, "footprint": Vector2(42, 22)},
	"fire_short_brazier": {"label": "Short Brazier", "kind": "ashen_fire", "fire": 1, "footprint": Vector2(92, 38)},
	"fire_tripod_brazier": {"label": "Tripod Brazier", "kind": "ashen_fire", "fire": 2, "footprint": Vector2(100, 44)},
	"fire_wall_brazier": {"label": "Wall Brazier", "kind": "ashen_fire", "fire": 3, "footprint": Vector2(64, 34)},
	"fire_fire_pit": {"label": "Fire Pit", "kind": "ashen_fire", "fire": 4, "footprint": Vector2(130, 50)},

	"ashen_sentinel": {"label": "Volcanic sentinel", "kind": "ashen_tree", "tree": 0},
	"ashen_windbent": {"label": "Wind-bent volcanic", "kind": "ashen_tree", "tree": 1},
	"ashen_elder": {"label": "Volcanic elder", "kind": "ashen_tree", "tree": 2},
	"tree_1": {"label": "Tiered tree", "kind": "tree", "tree": 0},
	"tree_2": {"label": "Windswept tree", "kind": "tree", "tree": 1},
	"tree_3": {"label": "Weeping tree", "kind": "tree", "tree": 2},
	"tree_4": {"label": "Branching tree", "kind": "tree", "tree": 3},
	"tree_5": {"label": "Sparse tree", "kind": "tree", "tree": 4},
	"fence_se_1": {"label": "Fence SE x1", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_se_1", "size": Vector2(116, 116), "anchor": Vector2(22, 66), "col": Vector2(72, 36)},
	"fence_se_2": {"label": "Fence SE x2", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_se_2", "size": Vector2(188, 152), "anchor": Vector2(22, 66), "col": Vector2(144, 72)},
	"fence_se_3": {"label": "Fence SE x3", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_se_3", "size": Vector2(260, 188), "anchor": Vector2(22, 66), "col": Vector2(216, 108)},
	"fence_se_4": {"label": "Fence SE x4", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_se_4", "size": Vector2(332, 224), "anchor": Vector2(22, 66), "col": Vector2(288, 144)},
	"fence_sw_1": {"label": "Fence SW x1", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_sw_1", "size": Vector2(116, 116), "anchor": Vector2(92, 66), "col": Vector2(-72, 36)},
	"fence_sw_2": {"label": "Fence SW x2", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_sw_2", "size": Vector2(188, 152), "anchor": Vector2(164, 66), "col": Vector2(-144, 72)},
	"fence_sw_3": {"label": "Fence SW x3", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_sw_3", "size": Vector2(260, 188), "anchor": Vector2(236, 66), "col": Vector2(-216, 108)},
	"fence_sw_4": {"label": "Fence SW x4", "kind": "wall", "fence": true, "dir": FENCE_DIR, "art": "fence_sw_4", "size": Vector2(332, 224), "anchor": Vector2(308, 66), "col": Vector2(-288, 144)},
	"kit_se_2": {"label": "Wall SE x2", "kind": "wall", "art": "wall_se_2", "size": Vector2(110, 152), "anchor": Vector2(8, 118), "col": Vector2(72, 36), "depth": Vector2(29, -14.5)},
	"kit_se_3": {"label": "Wall SE x3", "kind": "wall", "art": "wall_se_3", "size": Vector2(146, 170), "anchor": Vector2(8, 118), "col": Vector2(108, 54), "depth": Vector2(29, -14.5)},
	"kit_se_4": {"label": "Wall SE x4", "kind": "wall", "art": "wall_se_4", "size": Vector2(182, 188), "anchor": Vector2(8, 118), "col": Vector2(144, 72), "depth": Vector2(29, -14.5)},
	"kit_se_5": {"label": "Wall SE x5", "kind": "wall", "art": "wall_se_5", "size": Vector2(218, 206), "anchor": Vector2(8, 118), "col": Vector2(180, 90), "depth": Vector2(29, -14.5)},
	"kit_se_6": {"label": "Wall SE x6", "kind": "wall", "art": "wall_se_6", "size": Vector2(254, 224), "anchor": Vector2(8, 118), "col": Vector2(216, 108), "depth": Vector2(29, -14.5)},
	"kit_sw_2": {"label": "Wall SW x2", "kind": "wall", "art": "wall_sw_2", "size": Vector2(110, 152), "anchor": Vector2(102, 118), "col": Vector2(-72, 36), "depth": Vector2(-30, -15)},
	"kit_sw_3": {"label": "Wall SW x3", "kind": "wall", "art": "wall_sw_3", "size": Vector2(146, 170), "anchor": Vector2(138, 118), "col": Vector2(-108, 54), "depth": Vector2(-30, -15)},
	"kit_sw_4": {"label": "Wall SW x4", "kind": "wall", "art": "wall_sw_4", "size": Vector2(182, 188), "anchor": Vector2(174, 118), "col": Vector2(-144, 72), "depth": Vector2(-30, -15)},
	"kit_sw_5": {"label": "Wall SW x5", "kind": "wall", "art": "wall_sw_5", "size": Vector2(218, 206), "anchor": Vector2(210, 118), "col": Vector2(-180, 90), "depth": Vector2(-30, -15)},
	"kit_sw_6": {"label": "Wall SW x6", "kind": "wall", "art": "wall_sw_6", "size": Vector2(254, 224), "anchor": Vector2(246, 118), "col": Vector2(-216, 108), "depth": Vector2(-30, -15)},
	"kit_pillar": {"label": "Pillar", "kind": "wall", "art": "pillar", "size": Vector2(64, 120), "anchor": Vector2(31, 119), "col": Vector2(0, 0)},
	"kit_ruin_se": {"label": "Ruin SE", "kind": "wall", "art": "ruin_se", "size": Vector2(182, 158), "anchor": Vector2(-7, 143), "col": Vector2(144, 72), "poly": [Vector2(11, -56), Vector2(37, -69), Vector2(209, -17), Vector2(181, -2), Vector2(155, 11), Vector2(143, 11), Vector2(91, -4), Vector2(79, -9), Vector2(71, -13), Vector2(15, -53)]},
	"kit_ruin_sw": {"label": "Ruin SW", "kind": "wall", "art": "ruin_sw", "size": Vector2(182, 158), "anchor": Vector2(188, 143), "col": Vector2(-144, 72), "poly": [Vector2(-210, -18), Vector2(-38, -68), Vector2(-12, -55), Vector2(-72, -13), Vector2(-80, -8), Vector2(-88, -5), Vector2(-144, 11), Vector2(-152, 11), Vector2(-156, 10), Vector2(-182, -3)]},
	"grass9_corner_top": {"label": "Corner Top", "kind": "grass", "tall": false},
	"grass9_edge_ne": {"label": "Edge Ne", "kind": "grass", "tall": false},
	"grass9_corner_right": {"label": "Corner Right", "kind": "grass", "tall": false},
	"grass9_edge_nw": {"label": "Edge Nw", "kind": "grass", "tall": false},
	"grass9_center": {"label": "Center", "kind": "grass", "tall": false},
	"grass9_edge_se": {"label": "Edge Se", "kind": "grass", "tall": false},
	"grass9_corner_left": {"label": "Corner Left", "kind": "grass", "tall": false},
	"grass9_edge_sw": {"label": "Edge Sw", "kind": "grass", "tall": false},
	"grass9_corner_bottom": {"label": "Corner Bottom", "kind": "grass", "tall": false},
	"grass_tall_00": {"label": "Tall grass 1", "kind": "grass", "tall": true},
	"grass_tall_01": {"label": "Tall grass 2", "kind": "grass", "tall": true},
	"grass_tall_02": {"label": "Tall grass 3", "kind": "grass", "tall": true},
	"grass_tall_03": {"label": "Tall grass 4", "kind": "grass", "tall": true},
	"blight_rock_01": {"label": "Blightwood Rock 1", "kind": "wall", "rock": true, "dir": "res://assets/environment/blightwood/rocks/", "sort_dy": -3.0, "art": "rock_01", "size": Vector2(114, 128), "anchor": Vector2(57, 124), "col": Vector2(0, 0), "body": Vector2(41, 43), "poly": [Vector2(-41, -23), Vector2(0, -3), Vector2(41, -23), Vector2(0, -43)]},
	"blight_rock_02": {"label": "Blightwood Rock 2", "kind": "wall", "rock": true, "dir": "res://assets/environment/blightwood/rocks/", "sort_dy": 3.0, "art": "rock_02", "size": Vector2(133, 115), "anchor": Vector2(66, 111), "col": Vector2(0, 0), "body": Vector2(48, 45), "poly": [Vector2(-48, -21), Vector2(0, 3), Vector2(48, -21), Vector2(0, -45)]},
	"blight_rock_03": {"label": "Blightwood Rock 3", "kind": "wall", "rock": true, "dir": "res://assets/environment/blightwood/rocks/", "sort_dy": 7.0, "art": "rock_03", "size": Vector2(180, 137), "anchor": Vector2(90, 133), "col": Vector2(0, 0), "body": Vector2(65, 57), "poly": [Vector2(-65, -25), Vector2(0, 7), Vector2(65, -25), Vector2(0, -57)]},
	"dynamic_shrine": {"label":"Ancient Flame Shrine", "kind":"dynamic_shrine", "landmark":true, "footprint":Vector2(340,160)},
	"ancient_shrine": {"label": "Ancient Shrine", "kind": "wall", "landmark": true, "dir": "res://assets/environment/blightwood/ancient_shrine/", "sort_dy": -29.0, "art": "shrine_shelter_01", "size": Vector2(256, 256), "anchor": Vector2(129, 242), "col": Vector2(0, 0), "body": Vector2(87, 112), "poly": [Vector2(-87, -69), Vector2(0, -29), Vector2(86, -72), Vector2(0, -112)]},
	"ground9_corner_top": {"label": "Corner Top", "kind": "ground"},
	"ground9_edge_ne": {"label": "Edge Ne", "kind": "ground"},
	"ground9_corner_right": {"label": "Corner Right", "kind": "ground"},
	"ground9_edge_nw": {"label": "Edge Nw", "kind": "ground"},
	"ground9_center": {"label": "Center", "kind": "ground"},
	"ground9_edge_se": {"label": "Edge Se", "kind": "ground"},
	"ground9_corner_left": {"label": "Corner Left", "kind": "ground"},
	"ground9_edge_sw": {"label": "Edge Sw", "kind": "ground"},
	"ground9_corner_bottom": {"label": "Corner Bottom", "kind": "ground"},
	"temple_floor_center": {"label": "Center", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_center"},
	"temple_floor_center_b": {"label": "Center B", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_center_b"},
	"temple_floor_cracked_a": {"label": "Cracked A", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_cracked_a"},
	"temple_floor_cracked_b": {"label": "Cracked B", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_cracked_b"},
	"temple_floor_moss_a": {"label": "Mossy", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_moss_a"},
	"temple_floor_edge_nw": {"label": "Edge NW", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_edge_nw"},
	"temple_floor_edge_ne": {"label": "Edge NE", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_edge_ne"},
	"temple_floor_edge_se": {"label": "Edge SE", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_edge_se"},
	"temple_floor_edge_sw": {"label": "Edge SW", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_edge_sw"},
	"temple_floor_corner_top": {"label": "Corner Top", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_corner_top"},
	"temple_floor_corner_right": {"label": "Corner Right", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_corner_right"},
	"temple_floor_corner_bottom": {"label": "Corner Bottom", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_corner_bottom"},
	"temple_floor_corner_left": {"label": "Corner Left", "kind": "ground", "group": "Temple ground", "dir": "res://assets/environment/kosen_courtyard/floor_tiles/", "file": "floor9_corner_left"},
	"player_spawn": {"label": "Player spawn", "kind": "spawn"},
	"kunai": {"label": "Kunai (white glow)", "kind": "pickup", "gourd": "kunai"},
	"health_gourd": {"label": "Health gourd +25%", "kind": "pickup", "gourd": "health"},
	"chakra_gourd": {"label": "Chakra gourd +25%", "kind": "pickup", "gourd": "chakra"},
	"tag_bomb": {"label": "Tag bomb (explosive)", "kind": "pickup", "gourd": "tag_bomb"},
	"smoke_tag_bomb": {"label": "Smoke tag bomb", "kind": "pickup", "gourd": "smoke_tag_bomb"},
	"paper_tag": {"label": "Paper tag (throwable bomb)", "kind": "pickup", "gourd": "paper_tag"},
}
## Panel sections: [title, [ids]].
const CATEGORIES := [["Player spawn", ["player_spawn"]], ["Blightwood lights", ["blight_wooden_post", "blight_stone_pagoda", "blight_branch_lantern", "blight_stone_brazier", "blight_spirit_totem", "blight_fireflies"]], ["Ashen fire", ["fire_tall_pillar", "fire_short_brazier", "fire_tripod_brazier", "fire_wall_brazier", "fire_fire_pit"]], ["Volcanic trees", ["ashen_sentinel", "ashen_windbent", "ashen_elder"]], ["Trees", ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5"]], ["Bridges", ["bridge_short_wood_u", "bridge_short_wood_v", "bridge_medium_wood_u", "bridge_medium_wood_v", "bridge_long_wood_u", "bridge_long_wood_v", "bridge_short_rope_u", "bridge_short_rope_v", "bridge_medium_rope_u", "bridge_medium_rope_v", "bridge_long_rope_u", "bridge_long_rope_v", "bridge_short_damaged_u", "bridge_short_damaged_v", "bridge_medium_damaged_u", "bridge_medium_damaged_v", "bridge_long_damaged_u", "bridge_long_damaged_v"]], ["Fences", ["fence_se_1", "fence_se_2", "fence_se_3", "fence_se_4", "fence_sw_1", "fence_sw_2", "fence_sw_3", "fence_sw_4"]], ["Temple walls", ["kit_se_2", "kit_se_3", "kit_se_4", "kit_se_5", "kit_se_6", "kit_sw_2", "kit_sw_3", "kit_sw_4", "kit_sw_5", "kit_sw_6", "kit_pillar", "kit_ruin_se", "kit_ruin_sw"]], ["Grass", ["grass9_corner_top", "grass9_edge_ne", "grass9_corner_right", "grass9_edge_nw", "grass9_center", "grass9_edge_se", "grass9_corner_left", "grass9_edge_sw", "grass9_corner_bottom"]], ["Tall grass", ["grass_tall_00", "grass_tall_01", "grass_tall_02", "grass_tall_03"]], ["Ground / paths", ["ground9_corner_top", "ground9_edge_ne", "ground9_corner_right", "ground9_edge_nw", "ground9_center", "ground9_edge_se", "ground9_corner_left", "ground9_edge_sw", "ground9_corner_bottom"]], ["Temple ground", ["temple_floor_center", "temple_floor_center_b", "temple_floor_cracked_a", "temple_floor_cracked_b", "temple_floor_moss_a", "temple_floor_edge_nw", "temple_floor_edge_ne", "temple_floor_edge_se", "temple_floor_edge_sw", "temple_floor_corner_top", "temple_floor_corner_right", "temple_floor_corner_bottom", "temple_floor_corner_left"]], ["Blightwood rocks", ["blight_rock_01", "blight_rock_02", "blight_rock_03"]], ["Dynamic shrine", ["dynamic_shrine"]], ["Landmarks", ["ancient_shrine"]], ["Pickups", ["health_gourd", "chakra_gourd", "paper_tag", "tag_bomb", "smoke_tag_bomb", "kunai"]], ["River water", ["water9_corner_top", "water9_edge_ne", "water9_corner_right", "water9_edge_nw", "water9_center", "water9_edge_se", "water9_corner_left", "water9_edge_sw", "water9_corner_bottom", "waterfall_small"]], ["Grass banks", ["shore_grass_00", "shore_grass_01", "shore_grass_02", "shore_grass_03", "shore_grass_04", "shore_grass_05", "shore_grass_06", "shore_grass_07", "shore_grass_08", "shore_grass_09", "shore_grass_10", "shore_grass_11", "shore_grass_12", "shore_grass_13", "shore_grass_14", "shore_grass_15"]], ["Dirt banks", ["shore_dirt_00", "shore_dirt_01", "shore_dirt_02", "shore_dirt_03", "shore_dirt_04", "shore_dirt_05", "shore_dirt_06", "shore_dirt_07", "shore_dirt_08", "shore_dirt_09", "shore_dirt_10", "shore_dirt_11", "shore_dirt_12", "shore_dirt_13", "shore_dirt_14", "shore_dirt_15"]], ["Rocky banks", ["shore_rock_00", "shore_rock_01", "shore_rock_02", "shore_rock_03", "shore_rock_04", "shore_rock_05", "shore_rock_06", "shore_rock_07", "shore_rock_08", "shore_rock_09", "shore_rock_10", "shore_rock_11", "shore_rock_12", "shore_rock_13", "shore_rock_14", "shore_rock_15"]]]
## Distance kept between a new object and the player / enemies so nothing is dropped on top of someone.
const ACTOR_CLEARANCE := 36.0
## Ground footprint of a floating pickup (selection outline only; it never blocks).
const PICKUP_FOOTPRINT := Vector2(40, 20)
## Health gourds scattered over a layout that has never had any (first run / pre-v5 saves).
const DEFAULT_GOURDS := 5
## Chakra gourds scattered over a layout saved before they existed (and on a fresh one).
const DEFAULT_CHAKRA_GOURDS := 3

static var _tree_cache: Array = []
static var _ashen_cache: Array = []
static var _fire_cache: Array = []

static func fire_info(index: int) -> Dictionary:
	if _fire_cache.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AshenFireProp.MANIFEST))
		_fire_cache = manifest.fixtures
	return _fire_cache[index]


static var _blight_cache: Array = []
static func blight_info(index: int) -> Dictionary:
	if _blight_cache.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BlightwoodLight.MANIFEST))
		_blight_cache = manifest.fixtures
	return _blight_cache[index]


static func ashen_info(index: int) -> Dictionary:
	if _ashen_cache.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/ashen_trees/ashen-trees.art.json"))
		_ashen_cache = manifest.trees
	return _ashen_cache[index]


## Catalog entry for an id, including the arena's own placeholder walls ("base_N").
static func def_of(id: String) -> Dictionary:
	if CATALOG.has(id):
		return CATALOG[id]
	if id.begins_with("base_") and id.substr(5).is_valid_int():
		var n := id.substr(5).to_int()
		if n >= 0 and n < WorldScale.BLOCKS.size() and not WorldScale.is_placeholder_block(n):
			var b: Array = WorldScale.BLOCKS[n]
			return {"label": "Wall" if float(b[2]) >= WorldScale.WALL_ART_MIN_HEIGHT else "Block", "kind": "block", "footprint": b[1], "height": float(b[2])}
	if id.begins_with("bridge_") and not Bridge.assembly(id.substr(7)).is_empty():
		var a: Dictionary = Bridge.assembly(id.substr(7))
		var d := {"label": "%s %s %s" % [str(a.id).get_slice("_", 0).capitalize(), str(a.style).capitalize(), str(a.axis).to_upper()], "kind": "bridge", "assembly": str(a.id)}
		d["footprint"] = Bridge.deck_bounds(a).size
		return d
	return {}

var arena: TrainingArena
var save_path := SAVE_PATH
var autosave := true
## Each entry: {"id": String, "pos": Vector2, "nodes": Array[Node]}
var objects: Array[Dictionary] = []
var _serial := 0
## SAVE_VERSION of the layout last loaded (0 = none); the arena scatters the default gourds when it is below 5.
var loaded_version := 0
## True once the authored starting-area layer is part of this layout (it is saved, so the owner's edits to it stick).
var shrine_section_applied := false
## Undo / redo. Each group is one editor action (a click, a whole paint stroke, a fill) stored as small ops:
## ["add", id, pos] | ["remove", id, pos] | ["move", id, from, to]. Nothing else is stored, so it stays cheap.
const UNDO_LIMIT := 200
var _undo: Array = []
var _redo: Array = []
var _pending: Array = []
var _replaying := false
var _recording := true
var hidden_types: Dictionary = {}
var locked_types: Dictionary = {}  ## category -> true: cannot be picked, dragged, erased or painted over


static func tree_info(index: int) -> Dictionary:
	if _tree_cache.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BlossomGrove.MANIFEST))
		_tree_cache = manifest.trees
	return _tree_cache[index]


const GROUND_DIR := "res://assets/environment/blightwood/ground_path/"

const FENCE_DIR := "res://assets/environment/fence_kit/"

## The picture file of a ground tile: Blightwood path tiles live in GROUND_DIR, the stone temple floor
## (Ashen Ruins) names its own folder and file in the catalog.
static func ground_texture(id: String) -> Texture2D:
	var def := def_of(id)
	return load(String(def.get("dir", GROUND_DIR)) + String(def.get("file", id)) + ".png") as Texture2D

const KIT_DIR := "res://assets/environment/kosen_courtyard/wall_kit_v2/"
const WALL_THICKNESS := 18.0


static func wall_texture(id: String) -> Texture2D:
	var def := def_of(id)
	return load(String(def.get("dir", KIT_DIR)) + String(def.art) + ".png") as Texture2D


## Ground rectangle covering a wall piece's collider (a strip along `col`, WALL_THICKNESS deep).
static func wall_rect(def: Dictionary, pos: Vector2) -> Rect2:
	var pts := wall_collider_points(def)
	if pts.is_empty():
		var body: Vector2 = def.get("body", Vector2(16.0, WALL_THICKNESS))
		return Rect2(pos.x - body.x, pos.y - body.y, body.x * 2.0, body.y)
	var lo := pos + pts[0]
	var hi := lo
	for q: Vector2 in pts:
		lo = Vector2(minf(lo.x, pos.x + q.x), minf(lo.y, pos.y + q.y))
		hi = Vector2(maxf(hi.x, pos.x + q.x), maxf(hi.y, pos.y + q.y))
	return Rect2(lo, hi - lo)


## Collider polygon of a wall piece relative to its ground point (empty = point piece, a box from "body").
## An explicit "poly" wins (ruins, plinths); otherwise a parallelogram along `col` pushed back by `depth`
## (default straight up WALL_THICKNESS) so it covers the wall's end cap and thickness.
static func wall_collider_points(def: Dictionary) -> PackedVector2Array:
	var col: Vector2 = def.col
	if def.has("poly"):
		return PackedVector2Array(def.poly)
	if col == Vector2.ZERO:
		return PackedVector2Array()
	var depth: Vector2 = def.get("depth", Vector2(0.0, -WALL_THICKNESS))
	return PackedVector2Array([Vector2.ZERO, col, col + depth, depth])


## Nearest floor-diamond VERTEX (36a, 18b with a + b odd): where a wall piece's front-bottom-left corner sits.
static func iso_vertex(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	var k0 := int(floor(p.x / 36.0))
	var m0 := int(floor(p.y / 18.0))
	for k in [k0, k0 + 1]:
		for m in [m0, m0 + 1]:
			if posmod(k - m, 2) != 1:
				continue
			var c := Vector2(36.0 * k, 18.0 * m)
			var d := c.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


static func footprint_of(id: String) -> Vector2:
	var def := def_of(id)
	if def.kind == "wall":
		return wall_rect(def, Vector2.ZERO).size
	if def.kind in ["pickup", "spawn"]:
		return PICKUP_FOOTPRINT
	return Vector2(72, 36) if def.kind in ["grass", "ground"] else WorldScale.TREE_TRUNK_FOOTPRINT if def.kind in ["tree", "ashen_tree"] else def.footprint


## The solid ground rectangle (BLOCKS convention: bottom-centre `pos`, extends `depth` upward).
static func footprint_rect(id: String, pos: Vector2) -> Rect2:
	var fp := footprint_of(id)
	if def_of(id).kind == "wall":
		return wall_rect(def_of(id), pos)
	if def_of(id).kind == "bridge":
		return Rect2(pos + Bridge.deck_bounds(Bridge.assembly(str(def_of(id).assembly))).position, fp)
	if def_of(id).kind in ["grass", "ground"]:
		return Rect2(pos - fp * 0.5, fp)  # a grass tile is centred on its diamond cell, not standing on it
	return Rect2(pos.x - fp.x * 0.5, pos.y - fp.y, fp.x, fp.y)


static var _art_cache: Dictionary = {}


## The object's picture: [Texture2D, top-left world origin] for kinds drawn from a texture, else [null, ZERO].
static func art_texture(id: String, pos: Vector2) -> Array:
	var def := def_of(id)
	match String(def.kind):
		"bridge":
			var a: Dictionary = Bridge.assembly(str(def.assembly))
			var sock: Array = a.start_socket
			return [load(str(a.preview)) as Texture2D, pos - Vector2(float(sock[0]), float(sock[1]))]
		"dynamic_shrine":
			return [load(DynamicShrine.DIR + "assembled.png") as Texture2D,pos-DynamicShrine.FOOT]
		"water_fx":
			return [load(BlightwoodWater.DIR + "waterfall-icon.png") as Texture2D, pos-Vector2(64,169)]
		"ground":
			return [ground_texture(id), pos - Vector2(36, 18)]
		"grass":
			return [load(WindGrassTileset.DIR + id + ".png") as Texture2D, pos - Vector2(56, 136 if def.tall else 84)]
		"blight_light":
			var info := blight_info(int(def.light))
			return [load(str(info.path).replace(".png", "-assembled.png")) as Texture2D, pos-Vector2(float(info.foot_anchor[0]), float(info.foot_anchor[1]))]
		"fireflies":
			return [load("res://assets/vfx/blightwood_lights/firefly-icon.png") as Texture2D, pos-Vector2(16, 16)]
		"ashen_fire":
			var info := fire_info(int(def.fire))
			return [load(str(info.path)) as Texture2D,pos-Vector2(float(info.foot_anchor[0]),float(info.foot_anchor[1]))]
		"ashen_tree":
			var info := ashen_info(int(def.tree))
			return [load(str(info.texture)) as Texture2D, pos - Vector2(float(info.anchor[0]), float(info.anchor[1]))]
		"tree":
			var info := tree_info(int(def.tree))
			return [load(str(info.texture)) as Texture2D, pos - Vector2(float(info.anchor[0]), float(info.anchor[1]))]
		"wall":
			return [wall_texture(id), pos - (def.anchor as Vector2)]
		"spawn":
			return [SpawnMarker.icon(), pos - SpawnMarker.FOOT]
		"pickup":
			var icon := HealthGourd.icon(str(def.get("gourd", "health")))
			if icon != null:
				return [icon, pos - Vector2(icon.get_width() * 0.5, icon.get_height() * 0.5 + HealthGourd.FLOAT_HEIGHT)]
	return [null, Vector2.ZERO]


## The rectangle that exactly bounds the object's VISIBLE art (transparent padding trimmed). Used for the
## builder's dimension boxes, hover and selection, so a box never covers more than the picture.
static func art_rect(id: String, pos: Vector2) -> Rect2:
	var at := art_texture(id, pos)
	var tex: Texture2D = at[0]
	if tex == null:
		return hit_rect(id, pos)  # placeholder blocks have no texture: their drawn volume is the art
	if not _art_cache.has(id):
		var used := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var r := img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				used = r
		_art_cache[id] = used
	var u: Rect2i = _art_cache[id]
	return Rect2((at[1] as Vector2) + Vector2(u.position), Vector2(u.size))


static var _alpha_images := {}


## True when `point` lands on a visible pixel of the object's art (within `reach` px, so thin pieces stay clickable).
## Pieces with no texture (placeholder blocks) fall back to their drawn volume.
static func art_pixel_hit(id: String, pos: Vector2, point: Vector2, reach := 2) -> bool:
	var at := art_texture(id, pos)
	var tex: Texture2D = at[0]
	if tex == null:
		return hit_rect(id, pos).has_point(point)
	var local := point - (at[1] as Vector2)
	if not Rect2(Vector2.ZERO, tex.get_size()).grow(float(reach)).has_point(local):
		return false
	if not _alpha_images.has(id):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_alpha_images[id] = img
	var image: Image = _alpha_images[id]
	if image == null:
		return true
	var cx := int(floor(local.x))
	var cy := int(floor(local.y))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > 0.1:
				return true
	return false


## What a click on the object's picture should hit (the drawn volume, bigger than the solid base).
static func hit_rect(id: String, pos: Vector2) -> Rect2:
	var def := def_of(id)
	if def.kind == "dynamic_shrine":
		return Rect2(pos-DynamicShrine.FOOT,Vector2(544,480))
	if def.kind == "water_fx":
		return Rect2(pos-Vector2(64,169),Vector2(128,192))
	if def.kind == "ground":
		return Rect2(pos - Vector2(36, 18), Vector2(72, 36))
	if def.kind == "grass":
		return Rect2(pos - Vector2(56, 136 if def.tall else 84), Vector2(112, 160 if def.tall else 112))
	if def.kind == "spawn":
		return Rect2(pos - SpawnMarker.FOOT, Vector2(SpawnMarker.SIZE))
	if def.kind == "pickup":
		return Rect2(pos.x - 40.0, pos.y - 140.0, 80.0, 150.0)
	if def.kind == "blight_light":
		var info := blight_info(int(def.light))
		return Rect2(pos-Vector2(float(info.foot_anchor[0]), float(info.foot_anchor[1])), Vector2(float(info.size[0]),float(info.size[1])))
	if def.kind == "fireflies":
		return Rect2(pos-Vector2(110, 90), Vector2(220, 180))
	if def.kind == "ashen_fire":
		var info := fire_info(int(def.fire))
		return Rect2(pos-Vector2(float(info.foot_anchor[0]),float(info.foot_anchor[1])),Vector2(float(info.size[0]),float(info.size[1])))
	if def.kind == "ashen_tree":
		return Rect2(pos - Vector2(160,416),Vector2(320,448))
	if def.kind == "tree":
		return Rect2(pos.x - 110.0, pos.y - 330.0, 220.0, 350.0)
	if def.kind == "wall":
		return Rect2(pos - (def.anchor as Vector2), def.size)
	var fp: Vector2 = def.footprint
	return Rect2(pos.x - fp.x * 0.5, pos.y - fp.y - float(def.height), fp.x + fp.y * 0.5, fp.y + float(def.height))


func can_place(id: String, pos: Vector2) -> bool:
	if arena == null or def_of(id).is_empty():
		return false
	var rect := footprint_rect(id, pos).grow(8.0)
	if not arena.bounds.encloses(rect):
		return false
	if def_of(id).kind in ["grass", "ground", "pickup", "spawn", "fireflies", "water_fx", "bridge"]:
		return true  # grass and floating pickups never block anyone
	var actors: Array[Node] = []
	actors.append_array(get_tree().get_nodes_in_group("player"))
	actors.append_array(get_tree().get_nodes_in_group("enemy"))
	for a: Node in actors:
		if a is Node2D and rect.grow(ACTOR_CLEARANCE).has_point((a as Node2D).global_position):
			return false
	return true


func add(id: String, pos: Vector2, commit := true) -> Dictionary:
	if arena == null or def_of(id).is_empty():
		return {}
	var def := def_of(id)
	if def.kind == "spawn":
		for o in objects:
			if o.id == id:  # there is exactly one spawn: placing again moves it
				move(o, pos, commit)
				return o
	var nodes: Array[Node] = []
	_serial += 1
	if def.kind == "spawn":
		var marker := SpawnMarker.new()
		marker.position = pos
		arena.add_child(marker)
		nodes = [marker]
	elif def.kind == "bridge":
		var bridge := Bridge.make(str(def.assembly))
		bridge.position = pos
		arena.add_child(bridge)
		nodes = [bridge]
	elif def.kind == "dynamic_shrine":
		var shrine := DynamicShrine.new()
		shrine.name = "PlacedDynamicShrine%d" % _serial
		shrine.position = pos
		arena.add_child(shrine)
		nodes = [shrine]
	elif def.kind == "water_fx":
		var water := BlightwoodWater.new()
		water.waterfall = true
		water.position = pos
		arena.add_child(water)
		nodes = [water]
	elif def.has("water_role"):
		var water := BlightwoodWater.new()
		water.role = str(def.water_role)
		water.shore_family = str(def.get("shore_family", ""))
		water.shore_mask = int(def.get("shore_mask", 0))
		water.position = pos
		arena.get_node("Ground").add_child(water)
		nodes = [water]
	elif def.kind == "ground":
		var sprite := Sprite2D.new()
		sprite.name = "PlacedGround%d" % _serial
		sprite.texture = ground_texture(id)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = pos
		# Ground owns the floor at z=-1. Draw after its floor, below grass/actors.
		arena.get_node("Ground").add_child(sprite)
		nodes = [sprite]
	elif def.kind == "grass":
		var field := arena.get_node_or_null("WindGrassField") as WindGrassField
		if field == null:
			return {}
		var sprite := field.make_editable_sprite(id, pos)
		if bool(def.get("tall", false)):
			arena.add_child(sprite)
		else:
			# Flat grass is floor: it lives on the Ground layer so fences, walls and actors always draw over it.
			arena.get_node("Ground").add_child(sprite)
		nodes = [sprite]
	elif def.kind == "blight_light":
		var fixture := BlightwoodLight.new()
		fixture.name = "PlacedBlightwoodLight%d" % _serial
		fixture.data = blight_info(int(def.light))
		fixture.position = pos
		arena.add_child(fixture)
		var body := _make_trunk(pos)
		var shape := body.get_child(0) as CollisionShape2D
		(shape.shape as RectangleShape2D).size = def.footprint
		shape.position.y = -(def.footprint as Vector2).y*0.5
		nodes = [fixture, body]
	elif def.kind == "fireflies":
		var swarm := ForestFireflies.new()
		swarm.name = "PlacedForestFireflies%d" % _serial
		swarm.count = 32
		swarm.radius = Vector2(110, 90)
		swarm.position = pos
		swarm.seed_value = int(pos.x*37+pos.y*17)
		arena.add_child(swarm)
		nodes = [swarm]
	elif def.kind == "ashen_fire":
		var fire := AshenFireProp.new()
		fire.name = "PlacedAshenFire%d" % _serial
		fire.data = fire_info(int(def.fire))
		fire.position = pos
		arena.add_child(fire)
		var body := _make_trunk(pos)
		var shape := body.get_child(0) as CollisionShape2D
		(shape.shape as RectangleShape2D).size = def.footprint
		shape.position.y = -(def.footprint as Vector2).y*0.5
		nodes = [fire,body]
	elif def.kind == "ashen_tree":
		var tree := AshenTree.new()
		tree.name = "PlacedVolcanic%d" % _serial
		tree.data = ashen_info(int(def.tree))
		tree.auto_advance = true
		tree.position = pos
		arena.add_child(tree)
		nodes = [tree, _make_trunk(pos)]
	elif def.kind == "block":
		var fp: Vector2 = def.footprint
		var front := TrainingArena.Block.new(fp, float(def.height))
		front.name = "PlacedBlock%d" % _serial
		front.position = pos
		arena.add_child(front)
		var rear := TrainingArena.BlockRear.new(fp, float(def.height))
		rear.name = "PlacedBlockRear%d" % _serial
		rear.position = ArenaSort.rear_position(pos, fp)
		arena.add_child(rear)
		nodes = [front, rear]
	elif def.kind == "wall":
		nodes = _make_wall(id, pos)
	elif def.kind == "pickup":
		var gourd := HealthGourd.new()
		gourd.kind = str(def.get("gourd", "health"))
		gourd.name = "PlacedGourd%d" % _serial
		gourd.position = pos
		arena.add_child(gourd)
		nodes = [gourd]
	else:
		var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
		if grove == null:
			return {}
		var tree := grove.add_tree(int(def.tree), pos)
		nodes = [tree, _make_trunk(pos)]
	var obj := {"id": id, "pos": pos, "nodes": nodes}
	objects.append(obj)
	if def.kind in ["ground", "grass"] or def.has("water_role"):
		Bridge.raise_floors(arena.get_node_or_null("Ground"))
	_record(["add", id, pos])
	_apply_visibility(obj)
	if commit:
		_changed()
	return obj


## Bug fix (owner 2026-10-23, screenshot: standing behind a long temple wall, player visibly drew
## OVER the wall instead of being hidden by it): a single Sprite2D for a whole diagonal wall run had
## ONE global y-sort key at the run's MIDPOINT (see the removed comment below). Godot's y-sort only
## compares ONE position per node, so that single key can only be locally correct AT the midpoint --
## everywhere else along a multi-cell run (the ends most of all, exactly where the report's
## screenshot shows the player standing) the real local "am I in front of or behind the wall here"
## answer diverges from what the midpoint key says, and the player visibly draws through the wall.
## Fix: cut the texture into CELL_UNIT-aligned vertical slices (same `cell` grid the kit's own
## kit.json already uses) and give each slice its OWN sort key, linearly interpolated from the near
## corner's y to the far corner's y across the run -- the same idea as Block/BlockRear's two keys
## (front edge, back edge), generalized from 2 keys to N because a diagonal edge isn't a single
## constant-y line the way an axis-aligned box's edges are.
## Math (verified before implementing): the kit's build script (tools/gen_wall_kit_v2.py) unshears
## the source art (shift column x up by x//2), builds the run, then reshears it (shift column x DOWN
## by x//2) -- a strictly linear, content-independent mapping from image column to world position
## along the run for EVERY column of the final PNG, including the non-uniform end-cap regions. That
## means slicing evenly by PIXEL COLUMN (not needing to know the kit's internal cap/panel pixel
## layout) still gives a proportionally correct world position -- and therefore sort key -- per
## slice. `position_i + offset_i` is solved per slice to reproduce the EXACT same final screen pixels
## as the original single sprite (verified algebraically, see PR), so the only thing this changes is
## the sort key granularity; the baked-in art is pixel-identical to before.
const CELL_UNIT := Vector2(36.0, 18.0)  ## matches wall_kit_v2/kit.json's own "cell" grid


## Number of sort-key slices for a wall piece with ground run `col`. 1 (no slicing) for point pieces
## (pillar/ruin, col == ZERO); otherwise the run length in kit cells, which is also the number of
## distinct 36px-ish cell steps the kit's own generator chained together to build that piece.
static func _wall_slice_count(col: Vector2) -> int:
	if col == Vector2.ZERO:
		return 1
	return maxi(1, roundi(col.length() / CELL_UNIT.length()))


## Position + offset for slice `i` of `n` (texture columns [x0, x0+w)) so it draws at EXACTLY the
## same screen pixels as the original single sprite would have for that column range, while its own
## y-sort key is the LOCAL ground y at that slice's midpoint along the run (not the whole run's
## midpoint) -- see the derivation in the comment above `_make_wall`.
static func _wall_slice_transform(def: Dictionary, pos: Vector2, x0: float, w: float, full_w: float) -> Dictionary:
	var anchor: Vector2 = def.anchor
	var col: Vector2 = def.col
	var t := (x0 + w * 0.5) / full_w
	var sort_key := lerpf(pos.y, pos.y + col.y, t)
	var position := Vector2(pos.x, sort_key)
	var offset := Vector2(x0 - anchor.x, pos.y - anchor.y - sort_key)
	return {"position": position, "offset": offset, "sort_key": sort_key}


## [slice sprites..., collider]. Each slice sorts at its OWN local ground y (see _wall_slice_count/
## _wall_slice_transform); the collider stays a single thin parallelogram along the whole run --
## only the VISUAL sort is diagonal-aware, collision is already geometry-correct as-is.
func _make_wall(id: String, pos: Vector2) -> Array[Node]:
	var def := def_of(id)
	var col: Vector2 = def.col
	var tex := wall_texture(id)
	var full_w: float = tex.get_width()
	var n := _wall_slice_count(col)
	var nodes: Array[Node] = []
	var x0 := 0.0
	for i in n:
		var w: float = full_w / float(n) if i < n - 1 else full_w - x0
		var sprite := Sprite2D.new()
		sprite.name = "PlacedWall%d_%d" % [_serial, i]
		sprite.centered = false
		if n == 1:
			sprite.texture = tex
			sprite.offset = -(def.anchor as Vector2) - col * 0.5 - Vector2(0, float(def.get("sort_dy", 0.0)))
			sprite.position = pos + col * 0.5 + Vector2(0, float(def.get("sort_dy", 0.0)))
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(x0, 0, w, tex.get_height())
			sprite.texture = atlas
			var t := _wall_slice_transform(def, pos, x0, w, full_w)
			sprite.offset = t.offset
			sprite.position = t.position
			sprite.set_meta("x0", x0)
			sprite.set_meta("w", w)
		arena.add_child(sprite)
		nodes.append(sprite)
		x0 += w
	var body := StaticBody2D.new()
	body.name = "PlacedWallBody%d" % _serial
	var shape := ConvexPolygonShape2D.new()
	var pts := wall_collider_points(def)
	if pts.is_empty():
		var half: Vector2 = def.get("body", Vector2(14.0, 14.0))
		pts = PackedVector2Array([Vector2(-half.x, 0), Vector2(half.x, 0), Vector2(half.x, -half.y), Vector2(-half.x, -half.y)])
	shape.points = pts
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	arena.add_child(body)
	nodes.append(body)
	return nodes


func _make_trunk(pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "PlacedTrunk%d" % _serial
	var shape := RectangleShape2D.new()
	shape.size = WorldScale.TREE_TRUNK_FOOTPRINT
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -WorldScale.TREE_TRUNK_FOOTPRINT.y * 0.5)
	body.add_child(col)
	body.position = pos
	arena.add_child(body)
	return body


## Take over the trees BlossomGrove spawned at start so they can be picked, moved and deleted like anything else.
func adopt_grove() -> int:
	if arena == null:
		return 0
	var n := 0
	for i in WorldScale.BLOCKS.size():
		var front := arena.get_node_or_null("Block%d" % i)
		var rear := arena.get_node_or_null("BlockRear%d" % i)
		if front != null and rear != null:
			_serial += 1
			objects.append({"id": "base_%d" % i, "pos": WorldScale.BLOCKS[i][0], "nodes": [front, rear]})
			n += 1
	var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
	if grove == null:
		_changed(false)
		return n
	for i in mini(grove.trees.size(), 5):
		var tree: BlossomTree = grove.trees[i]
		_serial += 1
		objects.append({"id": "tree_%d" % (i + 1), "pos": tree.position, "nodes": [tree, _make_trunk(tree.position)]})
		n += 1
	_changed(false)
	return n


## Original field becomes the same editable objects as newly placed grass.
func adopt_grass() -> int:
	var field := arena.get_node_or_null("WindGrassField") as WindGrassField
	if field == null:
		return 0
	field.ground.clear()
	field.tall.clear()
	for tile: Dictionary in field.initial_tiles:
		add(tile.id, tile.pos, false)
	return field.initial_tiles.size()


static func type_of(id: String) -> String:
	var def := def_of(id)
	return "Player spawn" if def.kind == "spawn" else "Bridges" if def.kind == "bridge" else "Dynamic shrine" if def.kind == "dynamic_shrine" else "River water" if def.kind == "water_fx" else "Blightwood lights" if def.kind in ["blight_light", "fireflies"] else "Ashen fire" if def.kind == "ashen_fire" else "Volcanic trees" if def.kind == "ashen_tree" else "Blightwood rocks" if def.get("rock", false) else "Landmarks" if def.get("landmark", false) else str(def.get("group", "Ground / paths")) if def.kind == "ground" else "Pickups" if def.kind == "pickup" else "Tall grass" if def.kind == "grass" and def.tall else "Grass" if def.kind == "grass" else "Trees" if def.kind == "tree" else "Fences" if def.get("fence", false) else "Temple walls" if def.kind == "wall" else "Temple walls"


func type_visible(id: String) -> bool:
	return not bool(hidden_types.get(type_of(id), false))


func _apply_visibility(obj: Dictionary) -> void:
	for n: Node in obj.nodes:
		if is_instance_valid(n) and n is CanvasItem:
			(n as CanvasItem).visible = type_visible(obj.id)


func type_locked(id: String) -> bool:
	return bool(locked_types.get(type_of(id), false))


func set_type_locked(category: String, locked: bool) -> void:
	locked_types[category] = locked


## Every unlocked, visible object whose picture centre lies inside `area` (box select). Floor tiles count by tile centre.
func objects_in_rect(area: Rect2) -> Array:
	var out: Array = []
	for o in objects:
		if not type_visible(o.id) or type_locked(o.id):
			continue
		var c: Vector2 = o.pos
		if not is_floor_tile(o.id):
			c = art_rect(o.id, o.pos).get_center()
		if area.has_point(c):
			out.append(o)
	return out


func set_type_visible(category: String, shown: bool) -> void:
	hidden_types[category] = not shown
	for obj in objects:
		if type_of(obj.id) == category:
			_apply_visibility(obj)


## True for a floor-layer object: ground tiles and flat (non-tall) grass tiles. They replace each other.
static func is_floor_tile(id: String) -> bool:
	var def := def_of(id)
	return def.get("kind", "") == "ground" or (def.get("kind", "") == "grass" and not bool(def.get("tall", false)))


## Every floor-layer object whose centre lies inside the floor cell centred at `cell`. Tiles that sit off the
## 72 x 36 lattice (the authored starting area) still count: exactly one lattice tile centre falls in each cell.
func floor_tiles_in_cell(cell: Vector2) -> Array:
	var out: Array = []
	for o in objects:
		if is_floor_tile(o.id):
			var d: Vector2 = (o.pos as Vector2) - cell
			if absf(d.x) / 36.0 + absf(d.y) / 18.0 < 1.0:
				out.append(o)
	return out


## Centre of the 72 x 36 floor-diamond (centres at (36k, 18m), k and m of equal parity) nearest to p.
static func lattice_center(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	var k0 := int(floor(p.x / 36.0))
	var m0 := int(floor(p.y / 18.0))
	for k in [k0, k0 + 1]:
		for m in [m0, m0 + 1]:
			if posmod(k - m, 2) != 0:
				continue
			var c := Vector2(36.0 * k, 18.0 * m)
			var d := c.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


## Every floor cell inside `area` that has no floor art on it (the white void). Water and tall props do not count as floor.
func void_cells(area: Rect2) -> Array:
	var covered := {}
	for o in objects:
		if is_floor_tile(o.id):
			covered[lattice_center(o.pos as Vector2)] = true
	var out: Array = []
	var k_lo := int(ceil(area.position.x / 36.0))
	var k_hi := int(floor(area.end.x / 36.0))
	var m_lo := int(ceil(area.position.y / 18.0))
	var m_hi := int(floor(area.end.y / 18.0))
	for m in range(m_lo, m_hi + 1):
		for k in range(k_lo, k_hi + 1):
			if posmod(k - m, 2) != 0:
				continue
			var c := Vector2(36.0 * k, 18.0 * m)
			if not covered.has(c) and area.encloses(Rect2(c - Vector2(36, 18), Vector2(72, 36))):
				out.append(c)
	return out


## The ground tile (any kind of floor tile) sitting on the floor cell centred at `cell`, or {}.
func ground_at(cell: Vector2) -> Dictionary:
	for o in floor_tiles_in_cell(cell):
		if def_of(o.id).kind == "ground":
			return o
	return {}


## Lay `id` on the floor cell centred at `cell`, replacing whatever floor tile (ground or flat grass) is already there.
## Returns true when something changed. Never commits: the caller does one `_changed()` after a whole stroke.
func paint_cell(id: String, cell: Vector2) -> bool:
	var def := def_of(id)
	if def.is_empty() or def.kind not in ["ground", "grass"] or arena == null:
		return false
	if not arena.bounds.encloses(Rect2(cell - Vector2(36, 18), Vector2(72, 36))):
		return false
	if is_floor_tile(id):
		var old := floor_tiles_in_cell(cell)
		for o in old:
			if type_locked(o.id):
				return false
		if old.size() == 1 and old[0].id == id and (old[0].pos as Vector2).distance_squared_to(cell) < 4.0:
			return false
		for o in old:
			remove(o, false)
	else:
		for o in objects:
			if o.id == id and (o.pos as Vector2).distance_squared_to(cell) < 4.0:
				return false
	return not add(id, cell, false).is_empty()


## Drop a stamp (items {id, x, y} relative to `origin`). Floor pieces replace the floor under them; props are placed
## only where `can_place` allows. One undo step. Returns the new objects.
func paste(items: Array, origin: Vector2) -> Array:
	var made: Array = []
	for it in items:
		var id: String = it.id
		if def_of(id).is_empty() or def_of(id).kind == "spawn":
			continue
		var pos := origin + Vector2(float(it.x), float(it.y))
		if is_floor_tile(id):
			if paint_cell(id, lattice_center(pos)):
				made.append(floor_tiles_in_cell(lattice_center(pos)).back())
		elif can_place(id, pos):
			var o := add(id, pos, false)
			if not o.is_empty():
				made.append(o)
	if not made.is_empty():
		_changed()
	return made


## Drop floor tiles stacked exactly on top of each other (older saves re-added the starting area on every boot).
func dedupe_floor() -> int:
	var seen := {}
	var dropped := 0
	for i in range(objects.size() - 1, -1, -1):
		var o: Dictionary = objects[i]
		if not is_floor_tile(o.id):
			continue
		var key := Vector2i(roundi(o.pos.x), roundi(o.pos.y))
		if seen.has(key):
			remove(o, false)
			dropped += 1
		else:
			seen[key] = true
	return dropped


func remove(obj: Dictionary, commit := true) -> void:
	if not objects.has(obj):
		return
	objects.erase(obj)
	_record(["remove", str(obj.id), obj.pos])
	var def := def_of(obj.id)
	if def.kind == "grass":
		(arena.get_node("WindGrassField") as WindGrassField).removed_editable(obj.id)
	for n: Node in obj.nodes:
		if not is_instance_valid(n):
			continue
		if def.kind == "tree" and n is BlossomTree:
			var grove := arena.get_node_or_null("BlossomGrove") as BlossomGrove
			if grove != null:
				grove.remove_tree(n as BlossomTree)
				continue
		n.queue_free()
	if commit:
		_changed()

func move(obj: Dictionary, pos: Vector2, commit := true) -> void:
	if not objects.has(obj):
		return
	_record(["move", str(obj.id), obj.pos, pos])
	obj.pos = pos
	var def := def_of(obj.id)
	var nodes: Array = obj.nodes
	if def.kind == "block":
		(nodes[0] as Node2D).position = pos
		(nodes[1] as Node2D).position = ArenaSort.rear_position(pos, def.footprint)
	elif def.kind == "wall":
		# nodes = [slice sprites..., body]. Each slice re-derives its own position/offset from the
		# x0/w it was built with (stashed as metadata at creation -- see _make_wall) via the SAME
		# formula used to create it, so a moved multi-cell wall keeps its per-slice sort keys correct
		# instead of collapsing back to a single whole-piece key.
		var full_w: float = wall_texture(obj.id).get_width()
		for i in nodes.size() - 1:
			var sprite := nodes[i] as Sprite2D
			if sprite.has_meta("x0"):
				var t := _wall_slice_transform(def, pos, sprite.get_meta("x0"), sprite.get_meta("w"), full_w)
				sprite.position = t.position
				sprite.offset = t.offset
			else:
				sprite.position = pos + (def.col as Vector2) * 0.5 + Vector2(0, float(def.get("sort_dy", 0.0)))
				sprite.offset = -(def.anchor as Vector2) - (def.col as Vector2) * 0.5 - Vector2(0, float(def.get("sort_dy", 0.0)))
		(nodes[nodes.size() - 1] as Node2D).position = pos
	else:
		for n: Node2D in nodes:
			n.position = pos
	if commit:
		_changed()



## Topmost object under a world point: the solid base wins over the (larger) picture so crowded trees stay pickable.
func hit_test(point: Vector2) -> Dictionary:
	# Tight picking (owner 2026-10-24: the old click boxes were far bigger than the art and the wrong assets got
	# selected / deleted). A prop is hit only where its picture has visible pixels (a 2px forgiveness ring), or on
	# its solid footprint. Overlaps: the piece drawn in front (larger y) wins, then the one placed last.
	var hit: Dictionary = {}
	var hit_y := -INF
	for i in objects.size():
		var o := objects[i]
		if not type_visible(o.id) or type_locked(o.id) or def_of(o.id).kind in ["grass", "ground"]:
			continue
		if not (art_pixel_hit(o.id, o.pos, point) or footprint_rect(o.id, o.pos).has_point(point)):
			continue
		if (o.pos as Vector2).y >= hit_y:
			hit_y = (o.pos as Vector2).y
			hit = o
	if not hit.is_empty():
		return hit
	var closest: Dictionary = {}
	var distance := INF
	for o in objects:
		if def_of(o.id).kind != "grass" or not type_visible(o.id) or type_locked(o.id):
			continue
		if art_pixel_hit(o.id, o.pos, point):
			var d := point.distance_squared_to(o.pos)
			if d < distance:
				distance = d
				closest = o
	if not closest.is_empty():
		return closest
	# Overlapping floor tiles (the off-lattice starting area next to painted ones): the nearest centre wins.
	var best: Dictionary = {}
	var best_norm := INF
	for i in range(objects.size() - 1, -1, -1):
		var o := objects[i]
		if def_of(o.id).kind == "ground" and type_visible(o.id) and not type_locked(o.id):
			var delta: Vector2 = point - o.pos
			var norm := absf(delta.x) / 36.0 + absf(delta.y) / 18.0
			if norm <= 1.0 and norm < best_norm - 0.0001:
				best_norm = norm
				best = o
	return best


## BLOCKS-style entries [pos, footprint, height] for the bandit nav.
func obstacles() -> Array:
	var out: Array = []
	for o in objects:
		var kind: String = def_of(o.id).kind
		if kind == "wall":
			out.append_array(_wall_obstacles(def_of(o.id), o.pos))
		elif kind not in ["grass", "ground", "pickup", "spawn", "fireflies", "water_fx", "bridge"]:
			out.append([o.pos, footprint_of(o.id), 0.0])
	return out


## One 36 x 36 nav box per floor cell the wall's collider crosses (the nav only knows axis-aligned boxes).
static func _wall_obstacles(def: Dictionary, pos: Vector2) -> Array:
	var col: Vector2 = def.col
	if col == Vector2.ZERO:
		var body: Vector2 = def.get("body", Vector2(16.0, 16.0))
		return [[pos, Vector2(body.x * 2.0, body.y), 0.0]]
	var out: Array = []
	var run := col
	var start := pos
	if def.has("poly"):
		var pp: PackedVector2Array = wall_collider_points(def)
		start = pos + pp[0]
		run = pp[1] - pp[0]
	var steps := maxi(1, int(round(absf(run.x) / 36.0)))
	var step := run / float(steps)
	for i in steps:
		var a := start + step * float(i)
		out.append([Vector2(a.x + step.x * 0.5, maxf(a.y, a.y + step.y)), Vector2(36, 36), 0.0])
	return out


func clear_all(commit := true) -> void:
	for o in objects.duplicate():
		remove(o, false)
	if commit:
		_changed()


func to_dict() -> Dictionary:
	var items: Array = []
	for o in objects:
		items.append({"id": o.id, "x": snappedf(o.pos.x, 0.01), "y": snappedf(o.pos.y, 0.01)})
	return {"version": SAVE_VERSION, "shrine_section": shrine_section_applied, "items": items}


func to_json_string() -> String:
	return JSON.stringify(to_dict(), "\t")


## A synchronous Web backup avoids losing recent edits to delayed IDBFS writeback.
## Existing installations without a backup still load their normal user:// file.
func _web_layout_read() -> String:
	if not OS.has_feature("web") or save_path != SAVE_PATH:
		return ""
	var result: Variant = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('shinobi-rush:world-layout:v1')||''}catch(e){return ''}})()",true)
	return str(result) if result != null else ""

func _web_layout_write(text: String) -> void:
	if not OS.has_feature("web") or save_path != SAVE_PATH:
		return
	# JSON quoting keeps layout data out of executable source. Storage may be denied/full;
	# the original FileAccess save remains available in that case.
	var action := "localStorage.removeItem('shinobi-rush:world-layout:v1')" if text.is_empty() else "localStorage.setItem('shinobi-rush:world-layout:v1',"+JSON.stringify(text)+")"
	JavaScriptBridge.eval("(function(){try{"+action+";return true}catch(e){return false}})()",true)

func save() -> bool:
	# An empty world is never persisted: it would make the next boot start with no trees or walls.
	if objects.is_empty():
		_web_layout_write("")
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(save_path)
		return true
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	var text := to_json_string()
	f.store_string(text)
	f.close()  # complete the write before the Web filesystem schedules persistence
	_web_layout_write(text)
	return true

## Rebuild a layout. Entries with an unknown id, bad numbers, outside the arena or on top of the spawn are skipped.
func load_dict(data: Dictionary) -> int:
	var was_recording := _recording
	_recording = false
	clear_all(false)
	loaded_version = int(data.get("version", 1))
	shrine_section_applied = bool(data.get("shrine_section", false))
	if int(data.get("version", 1)) < 2:
		for i in WorldScale.TREE_POSITIONS.size():
			add("tree_%d" % (i + 1), WorldScale.TREE_POSITIONS[i], false)
	if int(data.get("version", 1)) < 3:
		for i in WorldScale.BLOCKS.size():
			if not WorldScale.is_placeholder_block(i):
				add("base_%d" % i, WorldScale.BLOCKS[i][0], false)
	if int(data.get("version", 1)) < 4:
		adopt_grass()
	var made := 0
	var spawn := Vector2(0, 135)
	if arena != null and arena.has_node("Spawn"):
		if _default_spawn == Vector2.INF:
			_default_spawn = (arena.get_node("Spawn") as Node2D).position
		spawn = _default_spawn
	for item in data.get("items", []):
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == "player_spawn" and typeof(item.get("x")) in [TYPE_FLOAT, TYPE_INT] and typeof(item.get("y")) in [TYPE_FLOAT, TYPE_INT]:
			spawn = Vector2(float(item.x), float(item.y))  # keep other pieces clear of where the player will really stand
	for item in data.get("items", []):
		if typeof(item) != TYPE_DICTIONARY or def_of(str(item.get("id", ""))).is_empty():
			continue
		if typeof(item.get("x")) not in [TYPE_FLOAT, TYPE_INT] or typeof(item.get("y")) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var id := str(item.id)
		var pos := Vector2(float(item.x), float(item.y))
		var rect := footprint_rect(id, pos)
		if not pos.is_finite() or not arena.bounds.encloses(rect) or (def_of(id).kind not in ["grass", "ground", "pickup", "spawn", "fireflies", "water_fx", "bridge"] and rect.grow(60.0).has_point(spawn)):
			continue
		if not add(id, pos, false).is_empty():
			made += 1
	_recording = was_recording
	clear_history()
	_changed(false)
	_apply_spawn(true)
	return made


## Where the Ancient Shrine stands in the starting level, best spot first: north-east of the spawn, off the
## due-up and due-right lanes and clear of the Level 1 walls. The first one that fits is used.
const SHRINE_SPOTS: Array[Vector2] = [Vector2(330, -330), Vector2(-120, -400), Vector2(380, 560), Vector2(-700, -420)]


func has_id(id: String) -> bool:
	for o in objects:
		if o.id == id:
			return true
	return false


## Put the Ancient Shrine into the level if it is not there yet. Returns true when one was added.
func ensure_shrine() -> bool:
	if arena == null or has_id("ancient_shrine"):
		return false
	for spot in SHRINE_SPOTS:
		if can_place("ancient_shrine", spot) and not _overlaps_solid(footprint_rect("ancient_shrine", spot).grow(40.0)):
			add("ancient_shrine", spot, false)
			_changed(false)
			return true
	return false


func _overlaps_solid(rect: Rect2) -> bool:
	for b in WorldScale.live_blocks():
		var fp: Vector2 = b[1]
		if rect.intersects(Rect2(b[0].x - fp.x * 0.5, b[0].y - fp.y, fp.x, fp.y)):
			return true
	for o in objects:
		var kind: String = def_of(o.id).kind
		if kind not in ["grass", "pickup", "spawn", "fireflies", "bridge"] and rect.intersects(footprint_rect(o.id, o.pos)):
			return true
	return false


## Drop `count` health gourds at random spots clear of the spawn, enemies, other gourds and every solid object.
## Deterministic for a given `seed_value` (tests); a negative seed randomises. Returns how many were placed.
func scatter_gourds(count := DEFAULT_GOURDS, seed_value := -1, id := "health_gourd") -> int:
	if arena == null:
		return 0
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var area := arena.bounds.grow(-140.0)
	var made := 0
	var taken: Array[Vector2] = []
	for o in objects:
		if def_of(o.id).kind == "pickup":
			taken.append(o.pos)
	for attempt in 600:
		if made >= count:
			break
		var pos := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)).round()
		if _gourd_spot_ok(pos, taken):
			add(id, pos, false)
			taken.append(pos)
			made += 1
	loaded_version = SAVE_VERSION
	_changed(false)
	return made


## The starting set: health gourds, then chakra gourds, all spread apart. With `chakra_only` (a layout that
## already has its health gourds) just the chakra ones are added.
func scatter_defaults(chakra_only := false, seed_value := -1) -> void:
	if not chakra_only:
		scatter_gourds(DEFAULT_GOURDS, seed_value)
	scatter_gourds(DEFAULT_CHAKRA_GOURDS, seed_value + 1 if seed_value >= 0 else -1, "chakra_gourd")


func _gourd_spot_ok(pos: Vector2, taken: Array[Vector2]) -> bool:
	var spawn := Vector2(0, 135)
	if arena.has_node("Spawn"):
		spawn = (arena.get_node("Spawn") as Node2D).position
	if pos.distance_to(spawn) < 260.0:
		return false
	for t in taken:
		if t.distance_to(pos) < 420.0:
			return false
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D and (e as Node2D).global_position.distance_to(pos) < 200.0:
			return false
	var gourd_box := Rect2(pos.x - 40.0, pos.y - 140.0, 80.0, 150.0)  # what a click on the gourd would hit
	for o in objects:
		if def_of(o.id).kind in ["grass", "ground", "pickup", "spawn", "fireflies", "water_fx", "bridge"]:
			continue
		if footprint_rect(o.id, o.pos).grow(90.0).has_point(pos) or hit_rect(o.id, o.pos).grow(20.0).has_point(pos) or hit_rect(o.id, o.pos).intersects(gourd_box):
			return false
	return true


func load_saved() -> int:
	var backup: Variant = null
	var snapshot := _web_layout_read()
	if not snapshot.is_empty():
		var parser := JSON.new()
		if parser.parse(snapshot) == OK:
			backup = parser.data
	if typeof(backup) == TYPE_DICTIONARY and typeof(backup.get("items")) == TYPE_ARRAY and not backup.items.is_empty():
		var restored := load_dict(backup)
		if restored > 0:
			return restored
	if not FileAccess.file_exists(save_path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var items: Variant = parsed.get("items", [])
	if typeof(items) != TYPE_ARRAY or items.is_empty():
		return 0  # empty/garbled saves (older Clear-all autosaves) keep the default trees + walls
	var made := load_dict(parsed)
	if objects.is_empty():
		load_dict({"version": 1, "items": []})  # every entry was rejected: fall back to the defaults
	return made

## Fallback for a fresh boot with no per-machine user:// save (load_saved() returned 0): loads
## whatever layout was last published to GitHub (DEFAULT_LAYOUT_PATH), if any. Absent file is a
## normal, expected case (nothing has been published yet) -- just keeps the hand-authored defaults.
## `path` defaults to the real repo file; overridable so tests can point at a scratch user:// path
## instead of ever reading/writing the actual tracked res:// file during a test run.
func load_default_from_repo(path := DEFAULT_LAYOUT_PATH) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var items: Variant = parsed.get("items", [])
	if typeof(items) != TYPE_ARRAY or items.is_empty():
		return 0
	return load_dict(parsed)



## Where the player starts and respawns: the builder's spawn marker if one is placed, else the arena's own Spawn.
var _default_spawn := Vector2.INF


func spawn_point() -> Vector2:
	for o in objects:
		if def_of(o.id).kind == "spawn":
			return o.pos
	return _default_spawn


func _apply_spawn(teleport := false) -> void:
	if arena == null or not arena.has_node("Spawn"):
		return
	var marker := arena.get_node("Spawn") as Node2D
	if _default_spawn == Vector2.INF:
		_default_spawn = marker.position
	var at := spawn_point()
	marker.position = at
	var player := get_tree().get_first_node_in_group("player") as PlayerController if is_inside_tree() else null
	if player != null:
		player.spawn_position = at
		if teleport:
			player.global_position = at


func _changed(write := true) -> void:
	_apply_spawn()
	_flush_pending()
	if arena != null:
		arena.rebuild_nav()
	if write and autosave:
		save()


# ------------------------------------------------------------------ undo / redo
func _record(op: Array) -> void:
	if _replaying or not _recording:
		return
	_pending.append(op)
	_redo.clear()


func _flush_pending() -> void:
	if _pending.is_empty():
		return
	_undo.append(_pending)
	_pending = []
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


func clear_history() -> void:
	_undo.clear()
	_redo.clear()
	_pending.clear()


func can_undo() -> bool:
	return not _undo.is_empty() or not _pending.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func _find_exact(id: String, pos: Vector2) -> Dictionary:
	for i in range(objects.size() - 1, -1, -1):
		var o := objects[i]
		if o.id == id and (o.pos as Vector2).distance_squared_to(pos) < 0.25:
			return o
	return {}


## Undo the last editor action. Returns false when there is nothing to undo.
func undo() -> bool:
	_flush_pending()
	if _undo.is_empty():
		return false
	var group: Array = _undo.pop_back()
	_replaying = true
	for i in range(group.size() - 1, -1, -1):
		var op: Array = group[i]
		match op[0]:
			"add":
				var o := _find_exact(op[1], op[2])
				if not o.is_empty():
					remove(o, false)
			"remove":
				add(op[1], op[2], false)
			"move":
				var o2 := _find_exact(op[1], op[3])
				if not o2.is_empty():
					move(o2, op[2], false)
	_replaying = false
	_redo.append(group)
	_changed()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var group: Array = _redo.pop_back()
	_replaying = true
	for op: Array in group:
		match op[0]:
			"add":
				add(op[1], op[2], false)
			"remove":
				var o := _find_exact(op[1], op[2])
				if not o.is_empty():
					remove(o, false)
			"move":
				var o2 := _find_exact(op[1], op[2])
				if not o2.is_empty():
					move(o2, op[3], false)
	_replaying = false
	_undo.append(group)
	_changed()
	return true


## Lay `id` (a ground or flat-grass tile) on every floor cell that has no art. One undo step. Returns how many were laid.
func fill_void(id: String, area: Rect2) -> int:
	var made := 0
	for c: Vector2 in void_cells(area):
		if paint_cell(id, c):
			made += 1
	if made > 0:
		_changed()
	return made
