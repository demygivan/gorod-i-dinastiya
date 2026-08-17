class_name CityNavigationSystem
extends Node
## AStar-сетка города. Только пути и веса клеток, без мутаций GameState.


const DEFAULT_LAYOUT_PATH := "res://data/city/coastal_river_layout.txt"
const ROAD_WEIGHT := 1.0
const OFFROAD_WEIGHT := 10.0
const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@export_file("*.txt") var layout_file: String = DEFAULT_LAYOUT_PATH

var _astar: AStarGrid2D
var _width: int = 40
var _height: int = 30
var _road_cells: Array[Vector2i] = []
var _road_set: Dictionary = {}
var _footprint_clusters: Dictionary = {}  ## Vector2i -> Array[Vector2i]
var _house_homes: Array[Dictionary] = []  ## {slot_id, anchor, door}
var _production_doors: Array[Vector2i] = []
var _park_cells: Array[Vector2i] = []
var _park_west: Array[Vector2i] = []
var _park_east: Array[Vector2i] = []
var _park_set: Dictionary = {}
var _town_hall_cell: Vector2i = Vector2i(-1, -1)
var _town_hall_spawn_cells: Array[Vector2i] = []
var _grid_ready := false


func _ready() -> void:
	add_to_group("city_navigation")
	rebuild()


func is_ready_for_pathfinding() -> bool:
	return _grid_ready and _astar != null


func rebuild() -> void:
	var path := layout_file if not layout_file.is_empty() else DEFAULT_LAYOUT_PATH
	if not FileAccess.file_exists(path):
		push_error("CityNavigationSystem: layout not found: %s" % path)
		_grid_ready = false
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var layout := CityLayoutParser.parse(file.get_as_text())
	file.close()
	_build_from_layout(layout)


func find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_ready_for_pathfinding():
		return result
	if not _astar.is_in_boundsv(from_cell) or not _astar.is_in_boundsv(to_cell):
		return result
	if _astar.is_point_solid(from_cell) or _astar.is_point_solid(to_cell):
		return result

	var id_path := _astar.get_id_path(from_cell, to_cell)
	for point in id_path:
		result.append(Vector2i(point))
	if not result.is_empty() and result[0] == from_cell:
		result.remove_at(0)
	return result


func get_door_node(building_cell: Vector2i) -> Vector2i:
	var cluster: Array[Vector2i] = _cluster_for(building_cell)
	var best := NpcState.UNSET_CELL
	var best_dist := INF
	for cell in cluster:
		for offset in CARDINALS:
			var neighbor: Vector2i = cell + offset
			if not _is_road_cell(neighbor):
				continue
			var dist := Vector2(neighbor).distance_squared_to(Vector2(building_cell))
			if dist < best_dist:
				best_dist = dist
				best = neighbor
	if best.x >= 0:
		return best
	return _nearest_road(building_cell)


func get_house_homes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for home in _house_homes:
		result.append(home)
	return result


func pick_production_door(
	rng: RandomNumberGenerator,
	exclude: Vector2i = NpcState.UNSET_CELL,
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for door in _production_doors:
		if door != exclude:
			candidates.append(door)
	if candidates.is_empty():
		for door in _production_doors:
			candidates.append(door)
	if candidates.is_empty():
		return NpcState.UNSET_CELL
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func has_park() -> bool:
	return not _park_cells.is_empty()


func is_park_cell(cell: Vector2i) -> bool:
	return _park_set.has(cell)


func pick_park_end_cell(
	from_cell: Vector2i,
	rng: RandomNumberGenerator,
) -> Vector2i:
	if _park_west.is_empty() and _park_east.is_empty():
		if _park_cells.is_empty():
			return NpcState.UNSET_CELL
		return _park_cells[rng.randi_range(0, _park_cells.size() - 1)]

	var prefer_east := true
	if _park_set.has(from_cell) and not _park_east.is_empty() and not _park_west.is_empty():
		var mid_x := (_park_west[0].x + _park_east[0].x) / 2
		prefer_east = from_cell.x <= mid_x
	elif rng.randf() < 0.5:
		prefer_east = false

	var pool: Array[Vector2i] = _park_east if prefer_east else _park_west
	if pool.is_empty():
		pool = _park_west if prefer_east else _park_east
	var candidates: Array[Vector2i] = []
	for cell in pool:
		if cell != from_cell:
			candidates.append(cell)
	if candidates.is_empty():
		candidates = pool
	if candidates.is_empty():
		return NpcState.UNSET_CELL
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func pick_road_cell(
	origin: Vector2i,
	radius: int,
	rng: RandomNumberGenerator,
	exclude: Vector2i = NpcState.UNSET_CELL,
) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in _road_cells:
		if cell == exclude:
			continue
		if absi(cell.x - origin.x) + absi(cell.y - origin.y) > radius:
			continue
		candidates.append(cell)
	if candidates.is_empty():
		for cell in _road_cells:
			if cell != exclude:
				candidates.append(cell)
	if candidates.is_empty():
		return origin if origin.x >= 0 else Vector2i.ZERO
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func is_road_cell(cell: Vector2i) -> bool:
	return _is_road_cell(cell)


func is_in_bounds(cell: Vector2i) -> bool:
	return _astar != null and _astar.is_in_boundsv(cell)


func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not _astar.is_point_solid(cell)


func get_town_hall_cell() -> Vector2i:
	return _town_hall_cell


func get_town_hall_spawn_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _town_hall_spawn_cells:
		result.append(cell)
	return result


func pick_town_hall_spawn_cell(rng: RandomNumberGenerator) -> Vector2i:
	if not _town_hall_spawn_cells.is_empty():
		return _town_hall_spawn_cells[rng.randi_range(0, _town_hall_spawn_cells.size() - 1)]
	if _town_hall_cell.x >= 0:
		var door := get_door_node(_town_hall_cell)
		if door.x >= 0:
			return door
	return pick_road_cell(Vector2i.ZERO, 999, rng)


func get_grid_size() -> Vector2i:
	return Vector2i(_width, _height)


func _build_from_layout(layout: Dictionary) -> void:
	_width = int(layout.get("width", 40))
	_height = int(layout.get("height", 30))
	var cells: Dictionary = layout.get("cells", {})
	var footprints := CityLayoutParser.collect_building_footprint_cells(layout)
	_index_footprint_clusters(layout)

	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _width, _height)
	_astar.cell_size = Vector2(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()

	_road_cells.clear()
	_road_set.clear()

	for y in _height:
		for x in _width:
			var coord := Vector2i(x, y)
			var cell: CityLayoutParser.CellData = CityLayoutParser.get_cell(cells, x, y)
			if footprints.has(coord) or _is_solid_terrain(cell):
				_astar.set_point_solid(coord, true)
				continue
			if CityLayoutParser.is_road(cell):
				_astar.set_point_weight_scale(coord, ROAD_WEIGHT)
				_road_cells.append(coord)
				_road_set[coord] = true
			elif _is_offroad_walkable(cell):
				_astar.set_point_weight_scale(coord, OFFROAD_WEIGHT)
			elif _is_paved_walkable(cell):
				_astar.set_point_weight_scale(coord, ROAD_WEIGHT)
			else:
				_astar.set_point_solid(coord, true)

	_index_houses(layout)
	_index_production(layout)
	_index_park(layout)
	_index_town_hall(layout)
	_grid_ready = not _road_cells.is_empty()


func _index_footprint_clusters(layout: Dictionary) -> void:
	_footprint_clusters.clear()
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	for y in height:
		for x in width:
			var cell := CityLayoutParser.get_cell(cells, x, y)
			if not CityLayoutParser.is_building_slot(cell):
				continue
			var rect := CityLayoutParser.footprint_rect(Vector2i(x, y), cell, cells, width, height)
			var cluster: Array[Vector2i] = []
			for j in rect.size.y:
				for i in rect.size.x:
					cluster.append(rect.position + Vector2i(i, j))
			for cluster_cell in cluster:
				_footprint_clusters[cluster_cell] = cluster


func _index_houses(layout: Dictionary) -> void:
	_house_homes.clear()
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	for y in height:
		for x in width:
			var cell := CityLayoutParser.get_cell(cells, x, y)
			if not CityLayoutParser.is_house_slot(cell):
				continue
			var anchor := Vector2i(x, y)
			_house_homes.append({
				"slot_id": cell.slot_id,
				"anchor": anchor,
				"door": get_door_node(anchor),
			})


func _index_production(layout: Dictionary) -> void:
	_production_doors.clear()
	var seen := {}
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	for y in height:
		for x in width:
			var cell := CityLayoutParser.get_cell(cells, x, y)
			if not CityLayoutParser.is_production_slot(cell):
				continue
			var door := get_door_node(Vector2i(x, y))
			if door.x < 0 or seen.has(door):
				continue
			seen[door] = true
			_production_doors.append(door)


func _index_park(layout: Dictionary) -> void:
	_park_cells.clear()
	_park_west.clear()
	_park_east.clear()
	_park_set.clear()
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	var min_x := 999
	var max_x := -1
	for y in height:
		for x in width:
			var cell := CityLayoutParser.get_cell(cells, x, y)
			if not CityLayoutParser.is_park(cell):
				continue
			var coord := Vector2i(x, y)
			_park_cells.append(coord)
			_park_set[coord] = true
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	if _park_cells.is_empty():
		return
	for coord in _park_cells:
		if coord.x == min_x:
			_park_west.append(coord)
		if coord.x == max_x:
			_park_east.append(coord)


func _index_town_hall(layout: Dictionary) -> void:
	_town_hall_cell = CityLayoutParser.find_town_hall_cell(layout)
	_town_hall_spawn_cells = CityLayoutParser.find_town_hall_adjacent_roads(layout)


func _cluster_for(building_cell: Vector2i) -> Array[Vector2i]:
	var stored: Variant = _footprint_clusters.get(building_cell, null)
	if stored is Array:
		var typed: Array[Vector2i] = []
		for item in stored:
			typed.append(item)
		return typed
	return [building_cell]


func _is_solid_terrain(cell: CityLayoutParser.CellData) -> bool:
	if cell == null:
		return true
	match cell.symbol:
		CityLayoutParser.CellSymbol.WATER, \
		CityLayoutParser.CellSymbol.FOREST, \
		CityLayoutParser.CellSymbol.TOWN_HALL, \
		CityLayoutParser.CellSymbol.COMMERCIAL, \
		CityLayoutParser.CellSymbol.MARITIME, \
		CityLayoutParser.CellSymbol.RESIDENTIAL, \
		CityLayoutParser.CellSymbol.CEMETERY, \
		CityLayoutParser.CellSymbol.FISHERMAN, \
		CityLayoutParser.CellSymbol.BANDIT, \
		CityLayoutParser.CellSymbol.UNKNOWN:
			return true
		_:
			return false


func _is_offroad_walkable(cell: CityLayoutParser.CellData) -> bool:
	if cell == null:
		return false
	return (
		cell.symbol == CityLayoutParser.CellSymbol.GROUND
		or cell.symbol == CityLayoutParser.CellSymbol.FARMLAND
	)


func _is_paved_walkable(cell: CityLayoutParser.CellData) -> bool:
	if cell == null:
		return false
	return (
		cell.symbol == CityLayoutParser.CellSymbol.PLAZA
		or cell.symbol == CityLayoutParser.CellSymbol.GATE
		or cell.symbol == CityLayoutParser.CellSymbol.PARK
	)


func _is_road_cell(cell: Vector2i) -> bool:
	return _road_set.has(cell)


func _nearest_road(origin: Vector2i) -> Vector2i:
	if _is_road_cell(origin):
		return origin
	if _road_cells.is_empty():
		return origin

	var visited := {}
	var queue: Array[Vector2i] = [origin]
	visited[origin] = true
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in CARDINALS:
			var next_cell: Vector2i = current + offset
			if visited.has(next_cell):
				continue
			if _astar == null or not _astar.is_in_boundsv(next_cell):
				continue
			visited[next_cell] = true
			if _is_road_cell(next_cell):
				return next_cell
			queue.append(next_cell)
	return _road_cells[0]
