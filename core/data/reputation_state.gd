class_name ReputationState
extends Resource
## Репутация игрока/династии. Изменения — только через команды (позже).


@export var owner_id: String = ""
@export var value: float = 50.0


func clamped_value(formula: ReputationFormula) -> float:
	if formula == null:
		return clampf(value, 0.0, 100.0)
	return clampf(value, formula.min_value, formula.max_value)


func to_dict() -> Dictionary:
	return {
		"owner_id": owner_id,
		"value": value,
	}


static func from_dict(data: Dictionary) -> ReputationState:
	var state := ReputationState.new()
	state.owner_id = str(data.get("owner_id", ""))
	state.value = float(data.get("value", 50.0))
	return state
