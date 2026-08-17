class_name NpcState
extends Resource
## Состояние одного NPC в GameState.


@export var id: String = ""
@export var archetype_id: String = ""
@export var cash: float = 0.0
@export var relationship_to_player: float = 50.0
@export var reputation_opinion: float = 50.0

@export var last_purchase_day: int = 0
@export var last_purchase_good_id: String = ""
@export var last_purchase_business_id: String = ""
@export var last_purchase_success: bool = false
@export var last_purchase_note: String = ""
@export var campaign_vote_bonus: float = 0.0
@export var demand_goods: Dictionary = {}  ## good_id (String) -> qty (int)

enum MovementState { IDLE_WANDER, MOVING_TO_GOAL, AT_HOME, RETURNING_HOME, STROLLING_PARK }

const UNSET_CELL := Vector2i(-1, -1)

@export var current_cell: Vector2i = UNSET_CELL
@export var home_cell: Vector2i = UNSET_CELL
@export var home_slot_id: String = ""
@export var movement_state: int = MovementState.AT_HOME
@export var path_cells: Array[Vector2i] = []
@export var idle_ticks_left: int = 0
@export var activity_until_abs_minute: int = 0


func has_cell() -> bool:
	return current_cell.x >= 0 and current_cell.y >= 0


func is_at_home() -> bool:
	return movement_state == MovementState.AT_HOME


func get_archetype_name() -> String:
	return DataRegistry.get_npc_archetype_name(archetype_id)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"archetype_id": archetype_id,
		"cash": cash,
		"relationship_to_player": relationship_to_player,
		"reputation_opinion": reputation_opinion,
		"last_purchase_day": last_purchase_day,
		"last_purchase_good_id": last_purchase_good_id,
		"last_purchase_business_id": last_purchase_business_id,
		"last_purchase_success": last_purchase_success,
		"last_purchase_note": last_purchase_note,
		"campaign_vote_bonus": campaign_vote_bonus,
		"demand_goods": demand_goods.duplicate(),
		"current_cell": _cell_to_array(current_cell),
		"home_cell": _cell_to_array(home_cell),
		"home_slot_id": home_slot_id,
		"movement_state": movement_state,
		"path_cells": _path_to_array(path_cells),
		"idle_ticks_left": idle_ticks_left,
		"activity_until_abs_minute": activity_until_abs_minute,
	}


static func _cell_to_array(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


static func _path_to_array(path: Array[Vector2i]) -> Array:
	var result: Array = []
	for cell in path:
		result.append(_cell_to_array(cell))
	return result


static func from_dict(data: Dictionary) -> NpcState:
	var state := NpcState.new()
	state.id = str(data.get("id", ""))
	state.archetype_id = str(data.get("archetype_id", ""))
	state.cash = float(data.get("cash", 0.0))
	state.relationship_to_player = float(data.get("relationship_to_player", 50.0))
	state.reputation_opinion = float(data.get("reputation_opinion", 50.0))
	state.last_purchase_day = int(data.get("last_purchase_day", 0))
	state.last_purchase_good_id = str(data.get("last_purchase_good_id", ""))
	state.last_purchase_business_id = str(data.get("last_purchase_business_id", ""))
	state.last_purchase_success = bool(data.get("last_purchase_success", false))
	state.last_purchase_note = str(data.get("last_purchase_note", ""))
	state.campaign_vote_bonus = float(data.get("campaign_vote_bonus", 0.0))
	var raw_demand: Dictionary = data.get("demand_goods", {})
	state.demand_goods = raw_demand.duplicate()
	state.current_cell = _cell_from_variant(data.get("current_cell", UNSET_CELL))
	state.home_cell = _cell_from_variant(data.get("home_cell", UNSET_CELL))
	state.home_slot_id = str(data.get("home_slot_id", ""))
	state.movement_state = int(data.get("movement_state", MovementState.AT_HOME))
	state.path_cells = _path_from_variant(data.get("path_cells", []))
	state.idle_ticks_left = int(data.get("idle_ticks_left", 0))
	state.activity_until_abs_minute = int(data.get("activity_until_abs_minute", 0))
	return state


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
