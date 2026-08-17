@tool
class_name CitySlotMarker
extends Marker2D
## Маркер слота здания на карте. Метаданные для будущего CityLayoutAssigner.


@export var slot_id: String = ""
@export var is_fixed: bool = false
@export var forced_type: String = ""
@export var slot_kind: String = ""
@export var allowed_categories: Array[String] = []
@export var grid_x: int = -1
@export var grid_y: int = -1


func _ready() -> void:
	_sync_metadata()


func apply_from_cell(cell: CityLayoutParser.CellData, coord: Vector2i) -> void:
	if cell == null:
		return
	slot_id = cell.slot_id
	is_fixed = cell.is_fixed
	forced_type = cell.forced_type
	slot_kind = cell.slot_kind
	allowed_categories = cell.allowed_categories.duplicate()
	grid_x = coord.x
	grid_y = coord.y
	_sync_metadata()
	if Engine.is_editor_hint():
		name = "Slot_%s" % slot_id if not slot_id.is_empty() else "Slot_%d_%d" % [coord.x, coord.y]


func _sync_metadata() -> void:
	set_meta("slot_id", slot_id)
	set_meta("is_fixed", is_fixed)
	set_meta("forced_type", forced_type)
	set_meta("slot_kind", slot_kind)
	set_meta("allowed_categories", allowed_categories.duplicate())
	set_meta("grid_x", grid_x)
	set_meta("grid_y", grid_y)
