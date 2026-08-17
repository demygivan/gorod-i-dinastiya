class_name CityPlaceholderTileset
extends RefCounted
## Цветные заглушки 32×32 до появления арта в assets/art/tiles/.


const TILE_SIZE := 32

enum AtlasTile {
	GROUND,
	ROAD,
	BRIDGE,
	WATER,
	PLAZA,
	FARMLAND,
	FOREST,
	PARK,
	COLLISION,
}

const TILE_COLORS := {
	AtlasTile.GROUND: Color(0.42, 0.62, 0.36, 1.0),
	AtlasTile.ROAD: Color(0.45, 0.42, 0.38, 1.0),
	AtlasTile.BRIDGE: Color(0.55, 0.36, 0.22, 1.0),
	AtlasTile.WATER: Color(0.18, 0.42, 0.78, 1.0),
	AtlasTile.PLAZA: Color(0.78, 0.74, 0.62, 1.0),
	AtlasTile.FARMLAND: Color(0.76, 0.70, 0.32, 1.0),
	AtlasTile.FOREST: Color(0.14, 0.38, 0.16, 1.0),
	AtlasTile.PARK: Color(0.32, 0.58, 0.28, 1.0),
	AtlasTile.COLLISION: Color(0.0, 0.0, 0.0, 0.0),
}

const SOLID_TILES := {
	AtlasTile.WATER: true,
	AtlasTile.FOREST: true,
	AtlasTile.COLLISION: true,
}


static func create_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var image := Image.create(TILE_SIZE * TILE_COLORS.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
	for tile_index in TILE_COLORS:
		var rect := Rect2i(int(tile_index) * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
		image.fill_rect(rect, TILE_COLORS[tile_index])
		_paint_tile_pattern(image, int(tile_index))

	var texture := ImageTexture.create_from_image(image)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for tile_index in TILE_COLORS:
		atlas.create_tile(Vector2i(int(tile_index), 0))

	tile_set.add_source(atlas, 0)
	var source := tile_set.get_source(0) as TileSetAtlasSource
	if source != null:
		for tile_index in TILE_COLORS:
			if SOLID_TILES.has(tile_index):
				_add_full_tile_collision(source, Vector2i(int(tile_index), 0))
	return tile_set


static func atlas_coords_for(tile: AtlasTile) -> Vector2i:
	return Vector2i(int(tile), 0)


static func _add_full_tile_collision(atlas: TileSetAtlasSource, atlas_coords: Vector2i) -> void:
	var tile_data := atlas.get_tile_data(atlas_coords, 0)
	if tile_data == null:
		return
	var half := float(TILE_SIZE) * 0.5
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	]))


static func _paint_tile_pattern(image: Image, tile_index: int) -> void:
	var ox := tile_index * TILE_SIZE
	match tile_index:
		AtlasTile.FARMLAND:
			var furrow := Color(0.58, 0.48, 0.18, 1.0)
			for y in [6, 14, 22]:
				image.fill_rect(Rect2i(ox, y, TILE_SIZE, 2), furrow)
		AtlasTile.FOREST:
			var canopy := Color(0.08, 0.28, 0.10, 1.0)
			var highlight := Color(0.22, 0.50, 0.20, 1.0)
			image.fill_rect(Rect2i(ox + 3, 2, 16, 16), canopy)
			image.fill_rect(Rect2i(ox + 13, 8, 15, 15), highlight)
			image.fill_rect(Rect2i(ox + 5, 15, 14, 14), canopy)
		AtlasTile.PARK:
			var tuft := Color(0.22, 0.48, 0.20, 1.0)
			var light := Color(0.48, 0.72, 0.36, 1.0)
			image.fill_rect(Rect2i(ox + 4, 6, 8, 4), tuft)
			image.fill_rect(Rect2i(ox + 18, 12, 7, 5), light)
			image.fill_rect(Rect2i(ox + 10, 20, 9, 4), tuft)
		_:
			pass
