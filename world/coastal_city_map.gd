@tool
extends Node2D
## Прибрежная карта: ASCII-чертёж → TileMapLayer + слоты + застройка.


const DEFAULT_LAYOUT_PATH := "res://data/city/coastal_river_layout.txt"
const DEFAULT_SPAWN_POOL_PATH := "res://data/city/production_buildings.tres"
const BUSINESS_VISIT_OFFSET := Vector2(0, 42)
## Residential-only block west of the main grid (layout x < this).
const HOME_QUARTER_MAX_X := 12

@export_file("*.txt") var layout_file: String = DEFAULT_LAYOUT_PATH
@export_file("*.tres") var spawn_pool_path: String = DEFAULT_SPAWN_POOL_PATH
@export var tile_size: int = CityPlaceholderTileset.TILE_SIZE
@export var auto_build_on_ready: bool = true

@export_tool_button("Rebuild From Layout", "rebuild_from_layout")
var _rebuild_button

var _water_kind_grid: Dictionary = {}  ## Vector2i -> "river" | "sea"
var _business_positions: Dictionary = {}  ## business_type_id -> Vector2
var _spawn_pool: BuildingSpawnPool


func _ready() -> void:
	if auto_build_on_ready:
		rebuild_from_layout()
	if not Engine.is_editor_hint():
		_update_home_district_from_slots()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _try_issue_move_command(get_global_mouse_position()):
		get_viewport().set_input_as_handled()


func rebuild_from_layout() -> void:
	var path := layout_file if not layout_file.is_empty() else DEFAULT_LAYOUT_PATH
	if not FileAccess.file_exists(path):
		push_error("CoastalCityMap: layout not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var layout := CityLayoutParser.parse(file.get_as_text())
	file.close()

	CityLayoutBuilder.build_into(self, layout, tile_size)
	_spawn_placed_buildings()
	print("[CoastalCityMap] built %dx%d from %s" % [
		layout.get("width", 0),
		layout.get("height", 0),
		path,
	])


func set_water_kind_grid(grid: Dictionary) -> void:
	_water_kind_grid = grid.duplicate()


func get_water_kind(cell: Vector2i) -> String:
	return str(_water_kind_grid.get(cell, ""))


func get_slot_markers() -> Array[CitySlotMarker]:
	var result: Array[CitySlotMarker] = []
	var slots_root := get_node_or_null("slots")
	if slots_root == null:
		return result
	for child in slots_root.get_children():
		if child is CitySlotMarker:
			result.append(child)
	return result


func get_slot_by_id(slot_id: String) -> CitySlotMarker:
	for marker in get_slot_markers():
		if marker.slot_id == slot_id:
			return marker
	return null


func get_business_visit_position(business_id: String) -> Vector2:
	var business := GameState.get_business(business_id)
	var type_id := business.type_id if business != null else business_id
	var base: Vector2 = _business_positions.get(type_id, Vector2.ZERO)
	return base + BUSINESS_VISIT_OFFSET


func _get_spawn_pool() -> BuildingSpawnPool:
	if _spawn_pool != null:
		return _spawn_pool

	var path := spawn_pool_path if not spawn_pool_path.is_empty() else DEFAULT_SPAWN_POOL_PATH
	if not ResourceLoader.exists(path):
		push_error("CoastalCityMap: spawn pool not found: %s" % path)
		return null

	_spawn_pool = load(path) as BuildingSpawnPool
	return _spawn_pool


func _get_layout_seed() -> int:
	if Engine.is_editor_hint():
		return 12345
	if GameState.simulation_seed != 0:
		return GameState.simulation_seed

	var scenario := DataRegistry.get_scenario(GameState.DEFAULT_SCENARIO_ID)
	if scenario != null:
		return scenario.simulation_seed
	return 12345


const PLACEHOLDER_KIND_BY_SLOT := {
	"residential": "house",
	"commercial": "workshop",
	"maritime": "workshop",
	"town_hall": "town_hall",
	"cemetery": "cemetery",
	"fisherman": "workshop",
	"bandit": "hut",
}


func _spawn_placed_buildings() -> void:
	var buildings_root := get_node_or_null("Buildings")
	if buildings_root == null:
		return

	for child in buildings_root.get_children():
		child.queue_free()

	# Случайный пул отключён: на слотах стоят заглушки по slot_kind.
	_business_positions.clear()
	for slot in get_slot_markers():
		var kind: String = PLACEHOLDER_KIND_BY_SLOT.get(slot.slot_kind, "")
		if kind.is_empty():
			continue
		if slot.slot_kind == "commercial" and not _business_positions.has("bakery"):
			_business_positions["bakery"] = slot.position

		var view := PlacedBuildingView.new()
		view.setup_placeholder(kind)
		view.position = slot.position
		view.name = "Building_%s" % slot.slot_id
		buildings_root.add_child(view)
		if Engine.is_editor_hint() and buildings_root.owner != null:
			view.owner = buildings_root.owner


func _update_home_district_from_slots() -> void:
	var residential: Array[Vector2] = []
	var quarter: Array[Vector2] = []
	for marker in get_slot_markers():
		if marker.slot_kind != "residential":
			continue
		residential.append(marker.global_position)
		if marker.grid_x < HOME_QUARTER_MAX_X:
			quarter.append(marker.global_position)

	var source := quarter if not quarter.is_empty() else residential
	if source.is_empty():
		return

	var centroid := Vector2.ZERO
	for pos in source:
		centroid += pos
	centroid /= float(source.size())

	var home := get_node_or_null("PointsOfInterest/HomeDistrict")
	if home is Node2D:
		home.global_position = centroid


func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(Vector2(
		(float(cell.x) + 0.5) * float(tile_size),
		(float(cell.y) + 0.5) * float(tile_size),
	))


func world_to_cell(world_pos: Vector2) -> Vector2i:
	var layer := get_node_or_null("ground_layer") as TileMapLayer
	if layer != null and layer.tile_set != null:
		return layer.local_to_map(layer.to_local(world_pos))
	var local := to_local(world_pos)
	return Vector2i(
		floori(local.x / float(tile_size)),
		floori(local.y / float(tile_size)),
	)


func get_home_district_position() -> Vector2:
	var home := get_node_or_null("PointsOfInterest/HomeDistrict")
	if home is Node2D:
		return home.global_position
	return global_position


func _get_player_business_type_id() -> String:
	if Engine.is_editor_hint():
		return ""
	for business_id in GameState.businesses:
		var business: BusinessState = GameState.businesses[business_id]
		if business.owner_id == GameState.DEFAULT_PLAYER_ID:
			return business.type_id
	return ""


func _try_issue_move_command(world_pos: Vector2) -> bool:
	var target := _resolve_move_target(world_to_cell(world_pos))
	if target.x < 0:
		return false
	var command := MoveCharacterCommand.new()
	command.character_id = GameState.DEFAULT_CHARACTER_ID
	command.target_cell = target
	var result := CommandProcessor.execute(command.execute)
	return result.success


func _resolve_move_target(cell: Vector2i) -> Vector2i:
	var navigation := get_tree().get_first_node_in_group("city_navigation") as CityNavigationSystem
	if navigation == null or not navigation.is_ready_for_pathfinding():
		return Vector2i(-1, -1)
	if not navigation.is_in_bounds(cell):
		return Vector2i(-1, -1)
	if navigation.is_walkable(cell):
		return cell
	var door := navigation.get_door_node(cell)
	if navigation.is_walkable(door):
		return door
	return Vector2i(-1, -1)
