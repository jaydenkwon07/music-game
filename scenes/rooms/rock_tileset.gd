class_name RockTileSet
extends RefCounted
## The M4 lithic tileset (§3.2, Step 3): real cave rock in the palette, replacing
## M3's two flat swatches. Built procedurally in code so it needs no editor
## authoring step and stays pinned to EnvPalette — rewrite palette.json and the
## whole cave retints (§3.3). Real hand-painted tiles can replace this atlas later
## with no other change; nothing outside here knows how a tile looks.
##
## Drawn FLAT, in palette values, with form but NOT lighting (§8a, D-M4-10): the
## Step 2 PointLight2D system does the lighting, so any baked directional shading
## here would light the rock twice and read muddy. The only edge treatment is a
## geometric seam-crack where wall meets floor — form, not a light gradient.
##
## Atlas layout (20px tiles):
##   row 0 — floor: 3 speckle variants (cols 0-2) + 1 rare detail (col 3)
##   row 1 — wall:  16 tiles, one per 4-neighbour floor-adjacency mask (N E S W)
## The Room reads the tile size back from the built TileSet (§5.2).

const SOURCE_ID := 0

const FLOOR_ROW := 0
const WALL_ROW := 1
const FLOOR_BASE_VARIANTS := 3   # cols 0-2 are interchangeable floor
const FLOOR_DETAIL_VARIANTS := 2 # cols 3-4 are rare detail (a crack, two directions)
const FLOOR_COLS := FLOOR_BASE_VARIANTS + FLOOR_DETAIL_VARIANTS
const ATLAS_COLS := 16           # widest row is the 16 wall masks

# Neighbour-adjacency bits for the wall mask: set when that neighbour is floor.
const N := 1
const E := 2
const S := 4
const W := 8


## Atlas coord for a floor tile. `variant` 0..2 are base speckles; 3-4 are detail.
static func floor_atlas(variant: int) -> Vector2i:
	return Vector2i(clampi(variant, 0, FLOOR_COLS - 1), FLOOR_ROW)


## Atlas coord for a wall tile with the given floor-adjacency mask (0..15).
static func wall_atlas(mask: int) -> Vector2i:
	return Vector2i(mask & 15, WALL_ROW)


static func build(tile_px: int) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_px, tile_px)
	tile_set.add_physics_layer()     # layer 0
	tile_set.add_occlusion_layer()   # layer 0, so walls cast light shadow (§5.1)

	var source := TileSetAtlasSource.new()
	source.texture = _build_atlas(tile_px)
	source.texture_region_size = Vector2i(tile_px, tile_px)
	tile_set.add_source(source, SOURCE_ID)

	for v in FLOOR_COLS:
		source.create_tile(Vector2i(v, FLOOR_ROW))

	# Every wall mask gets the full-tile collision polygon and light occluder.
	var half := float(tile_px) * 0.5
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	for mask in 16:
		var coord := Vector2i(mask, WALL_ROW)
		source.create_tile(coord)
		var td := source.get_tile_data(coord, 0)
		td.set_collision_polygons_count(0, 1)
		td.set_collision_polygon_points(0, 0, square)
		var occ := OccluderPolygon2D.new()
		occ.polygon = square
		td.set_occluder(0, occ)

	return tile_set


# --- Pixel drawing (flat, palette values, form not lighting) ---

static func _build_atlas(tp: int) -> ImageTexture:
	var img := Image.create(ATLAS_COLS * tp, 2 * tp, false, Image.FORMAT_RGBA8)
	for v in FLOOR_COLS:
		_draw_floor(img, v * tp, FLOOR_ROW * tp, tp, v)
	for mask in 16:
		_draw_wall(img, mask * tp, WALL_ROW * tp, tp, mask)
	return ImageTexture.create_from_image(img)


## Floor: rock_shadow ground with a sparse grit of darker and lighter palette
## specks so a large floor never reads as one flat colour. Variant 3 adds a rare
## hairline crack. Deterministic per variant so the atlas is reproducible.
static func _draw_floor(img: Image, ox: int, oy: int, tp: int, variant: int) -> void:
	img.fill_rect(Rect2i(ox, oy, tp, tp), EnvPalette.color("rock_shadow"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant
	var deep := EnvPalette.color("rock_deep")
	var mid := EnvPalette.color("rock_mid")
	for _i in 14:
		img.set_pixel(ox + rng.randi_range(0, tp - 1), oy + rng.randi_range(0, tp - 1), deep)
	for _i in 6:
		img.set_pixel(ox + rng.randi_range(0, tp - 1), oy + rng.randi_range(0, tp - 1), mid)
	if variant >= FLOOR_BASE_VARIANTS:
		# A rare hairline crack; the two detail variants slope opposite ways so a
		# scatter of them never reads as one repeated diagonal.
		var void_c := EnvPalette.color("rock_void")
		var down_right := variant == FLOOR_BASE_VARIANTS
		for i in 9:
			var px := (4 + i) if down_right else (tp - 5 - i)
			img.set_pixel(ox + px, oy + 5 + int(i / 2), void_c)


## Wall: rock_mid stone with blocky grit, then a seam-crack on each edge that
## faces floor (§8a — geometric form, uniform on every exposed side, so it is an
## edge and not a directional light). Seeded by mask so different masks differ.
static func _draw_wall(img: Image, ox: int, oy: int, tp: int, mask: int) -> void:
	img.fill_rect(Rect2i(ox, oy, tp, tp), EnvPalette.color("rock_mid"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + mask
	var deep := EnvPalette.color("rock_deep")
	var lit := EnvPalette.color("rock_lit")
	for _i in 12:
		img.set_pixel(ox + rng.randi_range(0, tp - 1), oy + rng.randi_range(0, tp - 1), deep)
	for _i in 6:
		img.set_pixel(ox + rng.randi_range(0, tp - 1), oy + rng.randi_range(0, tp - 1), lit)

	var crack := EnvPalette.color("rock_void")  # the seam itself
	var lip := EnvPalette.color("rock_deep")     # one step into the wall
	if mask & N:
		for x in tp:
			img.set_pixel(ox + x, oy, crack)
			img.set_pixel(ox + x, oy + 1, lip)
	if mask & S:
		for x in tp:
			img.set_pixel(ox + x, oy + tp - 1, crack)
			img.set_pixel(ox + x, oy + tp - 2, lip)
	if mask & W:
		for y in tp:
			img.set_pixel(ox, oy + y, crack)
			img.set_pixel(ox + 1, oy + y, lip)
	if mask & E:
		for y in tp:
			img.set_pixel(ox + tp - 1, oy + y, crack)
			img.set_pixel(ox + tp - 2, oy + y, lip)
