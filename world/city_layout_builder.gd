@tool
class_name CityLayoutBuilder
extends RefCounted
## Сборка TileMapLayer и маркеров из результата CityLayoutParser.


const SOURCE_ID := 0


static func build_into(
	root: Node2D,
	layout: Dictionary,
	tile_size: int = CityPlaceholderTileset.TILE_SIZE,
) -> void:
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})

	var ground_layer := _get_layer(root, "ground_layer")
	var water_layer := _get_layer(root, "water_layer")
	var plaza_layer := _get_layer(root, "plaza_layer")
	var road_layer := _get_layer(root, "road_layer")
	var obstacle_layer := _get_layer(root, "obstacle_layer")
	var slots_root := _get_slots_root(root)

	var tile_set := CityPlaceholderTileset.create_tile_set()
	for layer in [ground_layer, water_layer, plaza_layer, road_layer, obstacle_layer]:
		if layer != null:
			layer.tile_set = tile_set
			layer.y_sort_enabled = true
			layer.collision_enabled = true
			layer.clear()
	slots_root.y_sort_enabled = true
	var buildings_root := root.get_node_or_null("Buildings") as Node2D
	if buildings_root != null:
		buildings_root.y_sort_enabled = true

	for child in slots_root.get_children():
		child.queue_free()

	var water_kinds := {}
	for y in height:
		for x in width:
			var cell: CityLayoutParser.CellData = cells.get(_key(x, y))
			if cell == null:
				continue
			var coord := Vector2i(x, y)
			_place_terrain_layers(
				ground_layer,
				water_layer,
				plaza_layer,
				road_layer,
				coord,
				cell,
				water_kinds,
			)
			_place_slot_marker(slots_root, coord, cell, tile_size, cells, width, height)

	_place_building_collisions(obstacle_layer, layout)

	if root.has_method("set_water_kind_grid"):
		root.set_water_kind_grid(water_kinds)

	_center_camera(root, width, height, tile_size)


static func _place_terrain_layers(
	ground_layer: TileMapLayer,
	water_layer: TileMapLayer,
	plaza_layer: TileMapLayer,
	road_layer: TileMapLayer,
	coord: Vector2i,
	cell: CityLayoutParser.CellData,
	water_kinds: Dictionary,
) -> void:
	match cell.symbol:
		CityLayoutParser.CellSymbol.GROUND:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.GROUND)
		CityLayoutParser.CellSymbol.ROAD:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.GROUND)
			_set_tile(road_layer, coord, CityPlaceholderTileset.AtlasTile.ROAD)
		CityLayoutParser.CellSymbol.BRIDGE:
			_set_tile(road_layer, coord, CityPlaceholderTileset.AtlasTile.BRIDGE)
		CityLayoutParser.CellSymbol.WATER:
			_set_tile(water_layer, coord, CityPlaceholderTileset.AtlasTile.WATER)
			water_kinds[coord] = (
				"sea" if cell.water_kind == CityLayoutParser.WaterKind.SEA else "river"
			)
		CityLayoutParser.CellSymbol.PLAZA:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.GROUND)
			_set_tile(plaza_layer, coord, CityPlaceholderTileset.AtlasTile.PLAZA)
		CityLayoutParser.CellSymbol.TOWN_HALL, \
		CityLayoutParser.CellSymbol.COMMERCIAL, \
		CityLayoutParser.CellSymbol.MARITIME, \
		CityLayoutParser.CellSymbol.RESIDENTIAL, \
		CityLayoutParser.CellSymbol.GATE, \
		CityLayoutParser.CellSymbol.CEMETERY, \
		CityLayoutParser.CellSymbol.FISHERMAN, \
		CityLayoutParser.CellSymbol.BANDIT:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.GROUND)
		CityLayoutParser.CellSymbol.FARMLAND:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.FARMLAND)
		CityLayoutParser.CellSymbol.FOREST:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.FOREST)
		CityLayoutParser.CellSymbol.PARK:
			_set_tile(ground_layer, coord, CityPlaceholderTileset.AtlasTile.PARK)
		_:
			pass


static func _place_slot_marker(
	slots_root: Node2D,
	coord: Vector2i,
	cell: CityLayoutParser.CellData,
	tile_size: int,
	cells: Dictionary,
	width: int,
	height: int,
) -> void:
	if cell.slot_id.is_empty():
		return

	var marker := CitySlotMarker.new()
	marker.apply_from_cell(cell, coord)
	var rect := CityLayoutParser.footprint_rect(coord, cell, cells, width, height)
	marker.position = Vector2(
		(float(rect.position.x) + float(rect.size.x) * 0.5) * float(tile_size),
		(float(rect.position.y) + float(rect.size.y) * 0.5) * float(tile_size),
	)
	slots_root.add_child(marker)
	if Engine.is_editor_hint():
		marker.owner = slots_root.owner if slots_root.owner != null else slots_root


static func _place_building_collisions(obstacle_layer: TileMapLayer, layout: Dictionary) -> void:
	if obstacle_layer == null:
		return
	var footprints := CityLayoutParser.collect_building_footprint_cells(layout)
	for cell in footprints:
		_set_tile(obstacle_layer, cell, CityPlaceholderTileset.AtlasTile.COLLISION)


static func _set_tile(layer: TileMapLayer, coord: Vector2i, atlas_tile: int) -> void:
	if layer == null:
		return
	layer.set_cell(
		coord,
		SOURCE_ID,
		CityPlaceholderTileset.atlas_coords_for(atlas_tile),
	)


static func _get_layer(root: Node2D, layer_name: String) -> TileMapLayer:
	var node := root.get_node_or_null(layer_name)
	return node as TileMapLayer


static func _get_slots_root(root: Node2D) -> Node2D:
	var node := root.get_node_or_null("slots")
	if node is Node2D:
		return node
	var slots := Node2D.new()
	slots.name = "slots"
	slots.y_sort_enabled = true
	root.add_child(slots)
	if Engine.is_editor_hint() and root.owner != null:
		slots.owner = root.owner
	return slots


static func _center_camera(root: Node2D, width: int, height: int, tile_size: int) -> void:
	var camera := root.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.position = Vector2(
		float(width * tile_size) * 0.5,
		float(height * tile_size) * 0.5,
	)


static func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]
