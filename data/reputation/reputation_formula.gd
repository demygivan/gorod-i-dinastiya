class_name ReputationFormula
extends Resource
## Параметры репутации игрока и её влияния на спрос.


@export var id: String = ""
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var default_value: float = 50.0

@export_group("Demand multiplier")
@export var demand_mult_at_min: float = 0.75
@export var demand_mult_at_max: float = 1.25


static func demand_multiplier(reputation_value: float, formula: ReputationFormula) -> float:
	if formula == null:
		return 1.0
	var t := inverse_lerp(formula.min_value, formula.max_value, reputation_value)
	return lerpf(formula.demand_mult_at_min, formula.demand_mult_at_max, t)
