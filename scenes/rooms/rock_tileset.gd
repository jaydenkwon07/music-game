class_name RockTileSet
extends RefCounted
## The cave tileset (§3.2). Rock is a Godot 4 TERRAIN in "match corners and sides"
## mode — the 47-tile blob (M5 Step 1, CLAUDE.md §8): the engine picks the tile per
## cell from its rock/floor neighbourhood, so walls can round and bevel instead of
## being stuck at 90°. `room.gd` no longer computes an adjacency mask by hand; it
## calls set_cells_terrain_connect and the terrain set does the rest.
##
## The atlas is GENERATED procedurally, not loaded from a hand-drawn PNG. The M5
## spec's letter was to load a drawn atlas, but the owner chose a procedural first
## pass (2026-09-19): it keeps the palette.json → whole-cave retint (§3.3) that a
## baked PNG would lose, and it iterates via screenshots. If a hand-drawn PNG is
## wanted later, only `_build_atlas` changes — the 47 tiles, peering bits, collision
## and layout stay put. This is the only file that knows how a tile looks (§4).
##
## Drawn FLAT, in palette values, form but NOT lighting (§8a, D-M4-10): the
## PointLight2D system lights the room, so baked directional shading here would light
## twice and go muddy. Tones and feel come from a RockStyle (M5 Step 2b): the floor
## reads LIGHTER than the rock body so the room is legible without the outline, with
## subtle facets and a distance-field contact seam (uniform on every exposed side, so
## corners resolve without a per-corner case) — see RockStyle and _draw_rock.
##
## Atlas layout (tiles are `tile_px` square):
##   row 0        — floor: 3 speckle variants (cols 0-2) + 2 rare detail (cols 3-4)
##   rows 1..     — the 47 rock blob tiles, ROCK_COLS per row, in _blob_configs order
## Floor tiles carry no terrain — floor variety stays a spatial hash in room.gd (§4).

const SOURCE_ID := 0
const TERRAIN_SET := 0
const ROCK_TERRAIN := 0

const FLOOR_ROW := 0
const FLOOR_BASE_VARIANTS := 3   # cols 0-2 are interchangeable floor
const FLOOR_DETAIL_VARIANTS := 2 # cols 3-4 are rare detail (a crack, two directions)
const FLOOR_COLS := FLOOR_BASE_VARIANTS + FLOOR_DETAIL_VARIANTS

const ROCK_ROW_START := 1
const ROCK_COLS := 12

# Internal facet/grit tones (palette NAMES). The value-gap tones (floor, rock),
# the seam tone and the feel NUMBERS live in RockStyle (@export, M5 Step 2b); these
# are the sub-tones the flat texture is built from — a lighter fleck and a darker
# crack around the body — and stay structural, not per-room tuning. The contact seam
# itself is a distance field (§8a): uniform on every floor-facing side, so it outlines
# corners with no per-corner case and no carved silhouette.
const _ROCK_FLECK := "rock_shadow"   # a lighter fleck on the dark rock body
const _ROCK_CRACK := "rock_void"     # a darker crack
const _ROCK_GRAIN := "rock_mid"      # a rare bright grain
const _FLOOR_PIT := "rock_deep"      # a darker pit in the floor
const _FLOOR_GRAIN := "rock_mid"     # a lighter grain
const _FLOOR_INK := "rock_void"      # crack / pebble ink

# Side bits for a blob config: which cardinal neighbours are rock.
const S_TOP := 1
const S_RIGHT := 2
const S_BOTTOM := 4
const S_LEFT := 8
# Corner bits: which diagonal neighbours are rock. A corner is only ever set when
# both its adjacent sides are (the constraint that reduces 256 combos to 47).
const C_TR := 1
const C_BR := 2
const C_BL := 4
const C_TL := 8


## Atlas coord for a floor tile. `variant` 0..2 are base speckles; 3-4 are detail.
static func floor_atlas(variant: int) -> Vector2i:
	return Vector2i(clampi(variant, 0, FLOOR_COLS - 1), FLOOR_ROW)


## The 47 valid corners-and-sides blob configurations, as [sides, corners] pairs,
## in a stable order. Tile i in the atlas is configs[i]; build() and _build_atlas
## both index this, so drawing and peering bits always agree.
static func _blob_configs() -> Array:
	var out: Array = []
	for sides in 16:
		var eligible: Array = []
		if (sides & S_TOP) and (sides & S_RIGHT):
			eligible.append(C_TR)
		if (sides & S_BOTTOM) and (sides & S_RIGHT):
			eligible.append(C_BR)
		if (sides & S_BOTTOM) and (sides & S_LEFT):
			eligible.append(C_BL)
		if (sides & S_TOP) and (sides & S_LEFT):
			eligible.append(C_TL)
		for subset in (1 << eligible.size()):
			var corners := 0
			for k in eligible.size():
				if subset & (1 << k):
					corners |= eligible[k]
			out.append([sides, corners])
	return out


static func _rock_coord(index: int) -> Vector2i:
	return Vector2i(index % ROCK_COLS, ROCK_ROW_START + index / ROCK_COLS)


static func build(tile_px: int, style: RockStyle = null) -> TileSet:
	if style == null:
		style = RockStyle.new()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_px, tile_px)
	tile_set.add_physics_layer()     # layer 0
	tile_set.add_occlusion_layer()   # layer 0, so walls cast light shadow (§5.1)

	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tile_set.add_terrain(TERRAIN_SET)
	tile_set.set_terrain_name(TERRAIN_SET, ROCK_TERRAIN, "rock")
	tile_set.set_terrain_color(TERRAIN_SET, ROCK_TERRAIN, EnvPalette.color(style.rock_tone))

	var source := TileSetAtlasSource.new()
	source.texture = _build_atlas(tile_px, style)
	source.texture_region_size = Vector2i(tile_px, tile_px)
	tile_set.add_source(source, SOURCE_ID)

	for v in FLOOR_COLS:
		source.create_tile(Vector2i(v, FLOOR_ROW))

	var half := float(tile_px) * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	var configs := _blob_configs()
	for i in configs.size():
		var sides: int = configs[i][0]
		var corners: int = configs[i][1]
		var coord := _rock_coord(i)
		source.create_tile(coord)
		var td := source.get_tile_data(coord, 0)
		td.terrain_set = TERRAIN_SET
		td.terrain = ROCK_TERRAIN
		_set_peering(td, sides, corners)
		# Collision stays a full 30px square regardless of the drawn bevel (§8): it
		# is impassable either way and the player can't tell.
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, square)
		var occ := OccluderPolygon2D.new()
		occ.polygon = square
		td.set_occluder(0, occ)

	return tile_set


static func _set_peering(td: TileData, sides: int, corners: int) -> void:
	if sides & S_TOP:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, ROCK_TERRAIN)
	if sides & S_RIGHT:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, ROCK_TERRAIN)
	if sides & S_BOTTOM:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, ROCK_TERRAIN)
	if sides & S_LEFT:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, ROCK_TERRAIN)
	if corners & C_TR:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, ROCK_TERRAIN)
	if corners & C_BR:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, ROCK_TERRAIN)
	if corners & C_BL:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, ROCK_TERRAIN)
	if corners & C_TL:
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, ROCK_TERRAIN)


# --- Pixel drawing (flat, palette values, form not lighting; placeholder only) ---

static func _build_atlas(tp: int, style: RockStyle) -> ImageTexture:
	var configs := _blob_configs()
	var rock_rows := (configs.size() + ROCK_COLS - 1) / ROCK_COLS
	var cols: int = maxi(FLOOR_COLS, ROCK_COLS)
	var img := Image.create(cols * tp, (ROCK_ROW_START + rock_rows) * tp, false, Image.FORMAT_RGBA8)
	for v in FLOOR_COLS:
		_draw_floor(img, v * tp, FLOOR_ROW * tp, tp, v, style)
	for i in configs.size():
		var coord := _rock_coord(i)
		_draw_rock(img, coord.x * tp, coord.y * tp, tp, configs[i][0], configs[i][1], i, style)
	return ImageTexture.create_from_image(img)


## Floor: the style's floor_tone ground (LIGHTER than the rock body, so the room
## reads without leaning on the outline), with sparse low-grit — darker pits and a
## few lighter grains, deterministic per variant so a room always paints the same.
## Variant 3 is a hairline crack, variant 4 a small pebble cluster.
static func _draw_floor(img: Image, ox: int, oy: int, tp: int, variant: int, style: RockStyle) -> void:
	img.fill_rect(Rect2i(ox, oy, tp, tp), EnvPalette.color(style.floor_tone))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant
	var pit := EnvPalette.color(_FLOOR_PIT)
	var grain := EnvPalette.color(_FLOOR_GRAIN)
	var ink := EnvPalette.color(_FLOOR_INK)
	for _i in style.floor_pit_count:
		_blob(img, ox, oy, tp, rng.randi_range(1, tp - 3), rng.randi_range(1, tp - 3), 2, pit)
	for _i in maxi(1, style.floor_pit_count / 2):
		_blob(img, ox, oy, tp, rng.randi_range(1, tp - 3), rng.randi_range(1, tp - 3), 2, grain)
	for _i in 2:
		img.set_pixel(ox + rng.randi_range(0, tp - 1), oy + rng.randi_range(0, tp - 1), ink)
	if variant == FLOOR_BASE_VARIANTS:
		for i in 9:  # a hairline crack sloping down-right
			img.set_pixel(ox + 4 + i, oy + 5 + int(i / 2), ink)
	elif variant > FLOOR_BASE_VARIANTS:
		var cx := tp / 2 + rng.randi_range(-4, 4)  # a small pebble cluster
		var cy := tp / 2 + rng.randi_range(-4, 4)
		for _i in 5:
			_blob(img, ox, oy, tp, cx + rng.randi_range(-3, 3), cy + rng.randi_range(-3, 3), 2, pit)
		for _i in 2:
			_blob(img, ox, oy, tp, cx + rng.randi_range(-3, 3), cy + rng.randi_range(-3, 3), 2, grain)


## Rock blob tile. A flat body in the style's rock_tone (DARKER than the floor) with
## subtle low-contrast facets — a lighter fleck, a darker crack, a rare bright grain,
## no directional gradient (the PointLights do the lighting, §8a). Then a
## distance-field CONTACT SEAM in the style's seam_tone where the rock nears floor:
## uniform on every floor-facing side, so it outlines corners with no per-corner case
## and no carved silhouette.
static func _draw_rock(img: Image, ox: int, oy: int, tp: int, sides: int, corners: int, index: int, style: RockStyle) -> void:
	img.fill_rect(Rect2i(ox, oy, tp, tp), EnvPalette.color(style.rock_tone))
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + index
	var fleck := EnvPalette.color(_ROCK_FLECK)
	var crack := EnvPalette.color(_ROCK_CRACK)
	var grain := EnvPalette.color(_ROCK_GRAIN)
	for _i in style.rock_facet_count:
		_blob(img, ox, oy, tp, rng.randi_range(2, tp - 4), rng.randi_range(2, tp - 4), rng.randi_range(2, 3), fleck)
	for _i in maxi(1, style.rock_facet_count - 2):
		img.set_pixel(ox + rng.randi_range(1, tp - 2), oy + rng.randi_range(1, tp - 2), crack)
	for _i in 2:
		img.set_pixel(ox + rng.randi_range(1, tp - 2), oy + rng.randi_range(1, tp - 2), grain)

	var seam := EnvPalette.color(style.seam_tone)
	if style.seam_px <= 0.0:
		return
	for y in tp:
		for x in tp:
			var gx := (float(x) + 0.5) / float(tp)
			var gy := (float(y) + 0.5) / float(tp)
			var dp := _dist_to_floor(gx, gy, sides, corners) * float(tp)
			if dp < style.seam_px:
				img.set_pixel(ox + x, oy + y, seam)


## Euclidean distance (in tile units) from a point in the centre rock cell to the
## nearest floor neighbour, over the 3×3 of rock/floor implied by (sides, corners).
## INF when the tile is fully interior — then nothing darkens and it is pure body.
static func _dist_to_floor(gx: float, gy: float, sides: int, corners: int) -> float:
	var best := INF
	best = _rect_dist(best, gx, gy, 0, -1, not (sides & S_TOP))
	best = _rect_dist(best, gx, gy, 1, 0, not (sides & S_RIGHT))
	best = _rect_dist(best, gx, gy, 0, 1, not (sides & S_BOTTOM))
	best = _rect_dist(best, gx, gy, -1, 0, not (sides & S_LEFT))
	best = _rect_dist(best, gx, gy, 1, -1, not (corners & C_TR))
	best = _rect_dist(best, gx, gy, 1, 1, not (corners & C_BR))
	best = _rect_dist(best, gx, gy, -1, 1, not (corners & C_BL))
	best = _rect_dist(best, gx, gy, -1, -1, not (corners & C_TL))
	return best


static func _rect_dist(best: float, gx: float, gy: float, dx: int, dy: int, is_floor: bool) -> float:
	if not is_floor:
		return best
	var cx := clampf(gx, float(dx), float(dx + 1))
	var cy := clampf(gy, float(dy), float(dy + 1))
	return minf(best, sqrt((gx - cx) * (gx - cx) + (gy - cy) * (gy - cy)))


## A small filled square of `col`, clamped to the tile — the unit of facet grit.
static func _blob(img: Image, ox: int, oy: int, tp: int, cx: int, cy: int, size: int, col: Color) -> void:
	for yy in size:
		for xx in size:
			var px := cx + xx
			var py := cy + yy
			if px >= 0 and px < tp and py >= 0 and py < tp:
				img.set_pixel(ox + px, oy + py, col)
