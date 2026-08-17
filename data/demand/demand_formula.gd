class_name DemandFormula
extends Resource
## Параметры агрегированного дневного спроса жителей и шкала цен 0–10.


const LEVEL_MIN := 0
const LEVEL_MAX := 10
## Уровень ≈ базовая цена (multiplier ~0.95).
const DEFAULT_LEVEL := 3

## Множитель при level=0 (−50% к базе).
const MULTIPLIER_AT_MIN := 0.5
## Множитель при level=10 (+100% к базе, ×2).
const MULTIPLIER_AT_MAX := 2.0

@export var id: String = ""
@export var demand_hour: int = 10
@export var price_sensitivity: float = 1.2

@export_group("Food consumption (per resident per day)")
@export var consume_chance_food: float = 0.75
@export var consume_min_food: int = 0
@export var consume_max_food: int = 2

@export_group("Drink consumption")
@export var consume_chance_drink: float = 0.35
@export var consume_min_drink: int = 0
@export var consume_max_drink: int = 1

@export_group("Other categories")
@export var consume_chance_default: float = 0.15
@export var consume_min_default: int = 0
@export var consume_max_default: int = 1


static func clamp_level(level: int) -> int:
	return clampi(level, LEVEL_MIN, LEVEL_MAX)


static func level_to_multiplier(level: int) -> float:
	var t := float(clamp_level(level)) / float(LEVEL_MAX)
	return lerpf(MULTIPLIER_AT_MIN, MULTIPLIER_AT_MAX, t)


static func compute_sale_price(base_price: float, level: int) -> float:
	return base_price * level_to_multiplier(level)


static func willingness_from_level(level: int, sensitivity: float) -> float:
	var price_mult := level_to_multiplier(level)
	if price_mult <= 0.0:
		return 0.0
	return pow(1.0 / price_mult, sensitivity)


func get_consume_chance(category: String) -> float:
	match category:
		"food":
			return consume_chance_food
		"drink":
			return consume_chance_drink
		_:
			return consume_chance_default


func get_consume_range(category: String) -> Vector2i:
	match category:
		"food":
			return Vector2i(consume_min_food, consume_max_food)
		"drink":
			return Vector2i(consume_min_drink, consume_max_drink)
		_:
			return Vector2i(consume_min_default, consume_max_default)
