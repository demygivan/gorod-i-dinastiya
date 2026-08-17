class_name LawEffects
extends RefCounted
## Модификаторы экономики от активных законов. Без мутаций.


static func get_daily_cost_multiplier(laws: Dictionary, current_day: int) -> float:
	var multiplier := 1.0
	for raw_law_id in laws:
		var law_state: LawState = laws[raw_law_id]
		if not _is_law_in_effect(law_state, current_day):
			continue

		var definition := DataRegistry.get_law(str(raw_law_id))
		if definition == null:
			continue

		multiplier *= _effect_multiplier(definition)

	return multiplier


static func _is_law_in_effect(law_state: LawState, current_day: int) -> bool:
	if law_state == null or not law_state.is_active:
		return false
	return not law_state.is_expired(current_day)


static func _effect_multiplier(definition: LawDefinition) -> float:
	match definition.effect_type:
		LawDefinition.EFFECT_TAX_REDUCTION:
			return 1.0 - definition.effect_value
		_:
			push_warning("LawEffects: unknown effect_type \"%s\"" % definition.effect_type)
			return 1.0
