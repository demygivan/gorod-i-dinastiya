class_name LawState
extends Resource
## Состояние одного закона в GameState.


const PERMANENT_EXPIRES_DAY := -1

@export var law_id: String = ""
@export var is_active: bool = false
@export var activated_day: int = 0
@export var expires_day: int = PERMANENT_EXPIRES_DAY


func is_expired(current_day: int) -> bool:
	if not is_active:
		return false
	if expires_day < 0:
		return false
	return current_day > expires_day


func get_remaining_days(current_day: int) -> int:
	if not is_active or expires_day < 0:
		return -1
	return maxi(expires_day - current_day, 0)


static func create_inactive(law_id: String) -> LawState:
	var state := LawState.new()
	state.law_id = law_id
	return state


static func activate(definition: LawDefinition, current_day: int) -> LawState:
	var state := LawState.new()
	state.law_id = definition.id
	state.is_active = true
	state.activated_day = current_day
	if definition.duration_days <= LawDefinition.DURATION_PERMANENT:
		state.expires_day = PERMANENT_EXPIRES_DAY
	else:
		state.expires_day = current_day + definition.duration_days
	return state


func to_dict() -> Dictionary:
	return {
		"law_id": law_id,
		"is_active": is_active,
		"activated_day": activated_day,
		"expires_day": expires_day,
	}


static func from_dict(data: Dictionary) -> LawState:
	var state := LawState.new()
	state.law_id = str(data.get("law_id", ""))
	state.is_active = bool(data.get("is_active", false))
	state.activated_day = int(data.get("activated_day", 0))
	state.expires_day = int(data.get("expires_day", PERMANENT_EXPIRES_DAY))
	return state
