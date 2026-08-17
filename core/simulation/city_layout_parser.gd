class_name CityLayoutParser
extends RefCounted
## Парсинг ASCII-чертежа города. Без Godot-нод, без мутаций GameState.


enum WaterKind { NONE, RIVER, SEA }

enum CellSymbol {
	UNKNOWN,
	GROUND,
	ROAD,
	BRIDGE,
	WATER,
	PLAZA,
	TOWN_HALL,
	COMMERCIAL,
	MARITIME,
	RESIDENTIAL,
	GATE,
	CEMETERY,
	FARMLAND,
	FOREST,
	PARK,
	FISHERMAN,
	BANDIT,
}

const SYM_GROUND := "."
const SYM_ROAD := "#"
const SYM_JUNCTION := "+"
const SYM_BRIDGE := "="
const SYM_WATER := "~"
const SYM_PLAZA := "P"
const SYM_TOWN_HALL := "H"
const SYM_COMMERCIAL := "S"
const SYM_MARITIME := "D"
const SYM_RESIDENTIAL := "R"
const SYM_GATE := "G"
const SYM_CEMETERY := "C"
const SYM_FARMLAND := "F"
const SYM_FOREST := "T"
const SYM_PARK := "A"
const SYM_FISHERMAN := "M"
const SYM_BANDIT := "B"

const SEA_ROW_WATER_RATIO := 0.5
## Keep in sync with tools/generate_coastal_layout.py and PlacedBuildingView.
const FOOTPRINT_TILES := 2
const TOWN_HALL_FOOTPRINT_TILES := 3


class CellData:
	var symbol: int = CellSymbol.UNKNOWN
	var water_kind: int = WaterKind.NONE
	var is_bridge: bool = false
	var bridge_over_water: bool = false
	var slot_id: String = ""
	var is_fixed: bool = false
	var forced_type: String = ""
	var allowed_categories: Array[String] = []
	var slot_kind: String = ""


static func parse(text: String) -> Dictionary:
	var rows := _normalize_rows(text)
	var height := rows.size()
	var width := _row_width(rows)
	var water_kinds := _classify_water(rows, width, height)

	var cells: Dictionary = {}
	for y in height:
		for x in width:
			var ch := _char_at(rows, x, y)
			var cell := _parse_cell(ch, Vector2i(x, y), water_kinds)
			cells[_cell_key(x, y)] = cell

	_mark_bridges_over_water(cells, width, height)
	return {
		"width": width,
		"height": height,
		"cells": cells,
	}


static func get_cell(cells: Dictionary, x: int, y: int) -> CellData:
	return cells.get(_cell_key(x, y), null)


static func is_road(cell: CellData) -> bool:
	if cell == null:
		return false
	return cell.symbol == CellSymbol.ROAD or cell.symbol == CellSymbol.BRIDGE


static func is_building_slot(cell: CellData) -> bool:
	if cell == null or cell.slot_id.is_empty():
		return false
	return cell.slot_kind != "gate"


static func is_house_slot(cell: CellData) -> bool:
	return cell != null and cell.slot_kind == "residential"


static func is_production_slot(cell: CellData) -> bool:
	if cell == null:
		return false
	return cell.slot_kind in ["commercial", "maritime", "fisherman"]


static func is_park(cell: CellData) -> bool:
	return cell != null and cell.symbol == CellSymbol.PARK


static func footprint_rect(
	coord: Vector2i,
	cell: CellData,
	cells: Dictionary,
	width: int,
	height: int,
) -> Rect2i:
	if cell.slot_kind == "town_hall":
		var hall_origin := coord - Vector2i.ONE
		return Rect2i(hall_origin, Vector2i(TOWN_HALL_FOOTPRINT_TILES, TOWN_HALL_FOOTPRINT_TILES))
	if cell.slot_kind == "gate":
		return Rect2i(coord, Vector2i.ONE)

	var size := FOOTPRINT_TILES
	var grow_x := -1 if _is_road_at(cells, coord + Vector2i.RIGHT) and not _is_road_at(cells, coord + Vector2i.LEFT) else 1
	var grow_y := -1 if _is_road_at(cells, coord + Vector2i.DOWN) and not _is_road_at(cells, coord + Vector2i.UP) else 1
	for pair in [
		Vector2i(grow_x, grow_y),
		Vector2i(-grow_x, grow_y),
		Vector2i(grow_x, -grow_y),
		Vector2i(-grow_x, -grow_y),
	]:
		var origin := Vector2i(
			coord.x if pair.x > 0 else coord.x - (size - 1),
			coord.y if pair.y > 0 else coord.y - (size - 1),
		)
		if _footprint_is_land(cells, coord, origin, size, width, height):
			return Rect2i(origin, Vector2i(size, size))
	return Rect2i(coord, Vector2i.ONE)


static func collect_building_footprint_cells(layout: Dictionary) -> Dictionary:
	var result := {}
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	for y in height:
		for x in width:
			var cell := get_cell(cells, x, y)
			if not is_building_slot(cell):
				continue
			var rect := footprint_rect(Vector2i(x, y), cell, cells, width, height)
			for j in rect.size.y:
				for i in rect.size.x:
					result[rect.position + Vector2i(i, j)] = true
	return result


static func find_town_hall_cell(layout: Dictionary) -> Vector2i:
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	for y in height:
		for x in width:
			var cell := get_cell(cells, x, y)
			if cell != null and cell.symbol == CellSymbol.TOWN_HALL:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Cardinal ROAD/BRIDGE cells around the 3×3 town-hall footprint.
## Neighbours of the `H` glyph itself are still hall tiles, so the footprint is required.
static func find_town_hall_adjacent_roads(layout: Dictionary) -> Array[Vector2i]:
	var hall := find_town_hall_cell(layout)
	if hall.x < 0:
		return []

	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var cells: Dictionary = layout.get("cells", {})
	var hall_cell := get_cell(cells, hall.x, hall.y)
	var rect := footprint_rect(hall, hall_cell, cells, width, height)
	var seen := {}
	var result: Array[Vector2i] = []
	for j in rect.size.y:
		for i in rect.size.x:
			var footprint_cell := rect.position + Vector2i(i, j)
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = footprint_cell + offset
				if seen.has(neighbor):
					continue
				if not is_road(get_cell(cells, neighbor.x, neighbor.y)):
					continue
				seen[neighbor] = true
				result.append(neighbor)
	return result


static func _normalize_rows(text: String) -> PackedStringArray:
	var lines := text.split("\n", false)
	while not lines.is_empty() and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)

	var rows: PackedStringArray = []
	for line in lines:
		rows.append(line.rstrip("\r"))
	return rows


static func _row_width(rows: PackedStringArray) -> int:
	var width := 0
	for line in rows:
		width = maxi(width, line.length())
	return width


static func _char_at(rows: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= rows.size():
		return " "
	var line := rows[y]
	if x < 0 or x >= line.length():
		return " "
	return line.substr(x, 1)


static func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func _parse_cell(ch: String, coord: Vector2i, water_kinds: Dictionary) -> CellData:
	var cell := CellData.new()
	match ch:
		SYM_GROUND:
			cell.symbol = CellSymbol.GROUND
		SYM_ROAD, SYM_JUNCTION:
			cell.symbol = CellSymbol.ROAD
		SYM_BRIDGE:
			cell.symbol = CellSymbol.BRIDGE
			cell.is_bridge = true
		SYM_WATER:
			cell.symbol = CellSymbol.WATER
			cell.water_kind = int(water_kinds.get(coord, WaterKind.RIVER))
		SYM_PLAZA:
			cell.symbol = CellSymbol.PLAZA
		SYM_TOWN_HALL:
			cell.symbol = CellSymbol.TOWN_HALL
			cell.slot_id = "town_hall"
			cell.is_fixed = true
			cell.forced_type = "town_hall"
			cell.slot_kind = "town_hall"
		SYM_COMMERCIAL:
			cell.symbol = CellSymbol.COMMERCIAL
			cell.slot_id = "commercial_%d_%d" % [coord.x, coord.y]
			cell.allowed_categories = ["commercial"]
			cell.slot_kind = "commercial"
		SYM_MARITIME:
			cell.symbol = CellSymbol.MARITIME
			cell.slot_id = "maritime_%d_%d" % [coord.x, coord.y]
			cell.allowed_categories = ["commercial_maritime"]
			cell.slot_kind = "maritime"
		SYM_RESIDENTIAL:
			cell.symbol = CellSymbol.RESIDENTIAL
			cell.slot_id = "residential_%d_%d" % [coord.x, coord.y]
			cell.allowed_categories = ["residential"]
			cell.slot_kind = "residential"
		SYM_GATE:
			cell.symbol = CellSymbol.GATE
			cell.slot_id = "gate_main"
			cell.slot_kind = "gate"
		SYM_CEMETERY:
			cell.symbol = CellSymbol.CEMETERY
			cell.slot_id = "cemetery_%d_%d" % [coord.x, coord.y]
			cell.is_fixed = true
			cell.forced_type = "cemetery"
			cell.slot_kind = "cemetery"
		SYM_FARMLAND:
			cell.symbol = CellSymbol.FARMLAND
		SYM_FOREST:
			cell.symbol = CellSymbol.FOREST
		SYM_PARK:
			cell.symbol = CellSymbol.PARK
		SYM_FISHERMAN:
			cell.symbol = CellSymbol.FISHERMAN
			cell.slot_id = "fisherman_%d_%d" % [coord.x, coord.y]
			cell.allowed_categories = ["commercial"]
			cell.slot_kind = "fisherman"
		SYM_BANDIT:
			cell.symbol = CellSymbol.BANDIT
			cell.slot_id = "bandit_%d_%d" % [coord.x, coord.y]
			cell.allowed_categories = ["commercial"]
			cell.slot_kind = "bandit"
		_:
			cell.symbol = CellSymbol.UNKNOWN
	return cell


static func _classify_water(rows: PackedStringArray, width: int, height: int) -> Dictionary:
	var water_cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if _char_at(rows, x, y) == SYM_WATER:
				water_cells.append(Vector2i(x, y))

	var sea_cells := {}
	var queue: Array[Vector2i] = []

	for y in height:
		var water_in_row := 0
		for x in width:
			if _char_at(rows, x, y) == SYM_WATER:
				water_in_row += 1
		if width <= 0:
			continue
		if float(water_in_row) / float(width) < SEA_ROW_WATER_RATIO:
			continue
		for x in width:
			if _char_at(rows, x, y) != SYM_WATER:
				continue
			var coord := Vector2i(x, y)
			if sea_cells.has(coord):
				continue
			sea_cells[coord] = true
			queue.append(coord)

	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if _char_at(rows, next.x, next.y) != SYM_WATER:
				continue
			if sea_cells.has(next):
				continue
			sea_cells[next] = true
			queue.append(next)

	var kinds := {}
	for coord in water_cells:
		kinds[coord] = WaterKind.SEA if sea_cells.has(coord) else WaterKind.RIVER
	return kinds


static func _is_road_at(cells: Dictionary, coord: Vector2i) -> bool:
	return is_road(get_cell(cells, coord.x, coord.y))


static func _is_plot_land(cell: CellData) -> bool:
	return cell != null and cell.symbol == CellSymbol.GROUND


static func _footprint_is_land(
	cells: Dictionary,
	anchor: Vector2i,
	origin: Vector2i,
	size: int,
	width: int,
	height: int,
) -> bool:
	for j in size:
		for i in size:
			var cell_coord := origin + Vector2i(i, j)
			if cell_coord.x < 0 or cell_coord.y < 0 or cell_coord.x >= width or cell_coord.y >= height:
				return false
			if cell_coord == anchor:
				continue
			if not _is_plot_land(get_cell(cells, cell_coord.x, cell_coord.y)):
				return false
	return true


static func _mark_bridges_over_water(cells: Dictionary, width: int, height: int) -> void:
	for y in height:
		for x in width:
			var cell: CellData = cells.get(_cell_key(x, y))
			if cell == null or not cell.is_bridge:
				continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: CellData = cells.get(_cell_key(x + offset.x, y + offset.y))
				if neighbor != null and neighbor.symbol == CellSymbol.WATER:
					cell.bridge_over_water = true
					break
