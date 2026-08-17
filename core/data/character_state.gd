class_name CharacterState
extends Resource
## Состояние играбельного персонажа династии в GameState.


const UNSET_CELL := Vector2i(-1, -1)

@export var id: String = ""
@export var current_cell: Vector2i = UNSET_CELL
@export var path_cells: Array[Vector2i] = []


func has_cell() -> bool:
	return current_cell.x >= 0 and current_cell.y >= 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"current_cell": _cell_to_array(current_cell),
		"path_cells": _path_to_array(path_cells),
	}


static func from_dict(data: Dictionary) -> CharacterState:
	var state := CharacterState.new()
	state.id = str(data.get("id", ""))
	state.current_cell = _cell_from_variant(data.get("current_cell", UNSET_CELL))
	state.path_cells = _path_from_variant(data.get("path_cells", []))
	return state


static func _cell_to_array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


static func _path_to_array(path: Array[Vector2i]) -> Array:
	var result: Array = []
	for cell in path:
		result.append(_cell_to_array(cell))
	return result


static func _cell_from_variant(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return UNSET_CELL


static func _path_from_variant(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for item in value:
			result.append(_cell_from_variant(item))
	return result
