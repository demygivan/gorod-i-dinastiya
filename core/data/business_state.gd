class_name BusinessState
extends Resource
## Состояние одного предприятия в GameState.

@export var id: String = ""
@export var type_id: String = ""
@export var owner_id: String = ""
@export var cash: float = 0.0
@export var storage: Dictionary = {}  ## good_id (String) -> quantity (int)
@export var price_levels: Dictionary = {}  ## good_id (String) -> level 0–10
@export var prices: Dictionary = {}  ## good_id (String) -> computed sale price (float)
@export var daily_revenue: float = 0.0
@export var daily_expenses: float = 0.0
@export var daily_missed_sales: int = 0

@export var last_tick_sales: int = 0
@export var last_tick_missed_sales: int = 0
@export var last_tick_revenue: float = 0.0


func get_display_name() -> String:
	if type_id.is_empty():
		return id
	return DataRegistry.get_business_type_name(type_id)


func get_price_level(good_id: String) -> int:
	if price_levels.has(good_id):
		return DemandFormula.clamp_level(int(price_levels.get(good_id, DemandFormula.DEFAULT_LEVEL)))
	return DemandFormula.DEFAULT_LEVEL


func get_sale_price(good_id: String) -> float:
	var base_price := DataRegistry.get_good_price(good_id)
	return DemandFormula.compute_sale_price(base_price, get_price_level(good_id))


func sync_prices_from_levels() -> void:
	for raw_good_id in price_levels:
		var good_id := str(raw_good_id)
		prices[good_id] = get_sale_price(good_id)


func get_storage_summary() -> String:
	if storage.is_empty():
		return LocaleService.trf("label.storage.empty")

	var parts: PackedStringArray = []
	for good_id in storage.keys():
		var quantity: int = int(storage.get(good_id, 0))
		if quantity <= 0:
			continue
		parts.append("%s=%d" % [DataRegistry.get_good_name(str(good_id)), quantity])
	return ", ".join(parts) if not parts.is_empty() else LocaleService.trf("label.storage.empty")


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type_id": type_id,
		"owner_id": owner_id,
		"cash": cash,
		"storage": storage.duplicate(),
		"price_levels": price_levels.duplicate(),
		"prices": prices.duplicate(),
		"daily_revenue": daily_revenue,
		"daily_expenses": daily_expenses,
		"daily_missed_sales": daily_missed_sales,
		"last_tick_sales": last_tick_sales,
		"last_tick_missed_sales": last_tick_missed_sales,
		"last_tick_revenue": last_tick_revenue,
	}


static func from_dict(data: Dictionary) -> BusinessState:
	var state := BusinessState.new()
	state.id = str(data.get("id", ""))
	state.type_id = str(data.get("type_id", data.get("business_type", "")))
	state.owner_id = str(data.get("owner_id", ""))
	state.cash = float(data.get("cash", 0.0))
	state.storage = data.get("storage", {}).duplicate()
	state.price_levels = data.get("price_levels", {}).duplicate()
	state.prices = data.get("prices", {}).duplicate()
	state.daily_revenue = float(data.get("daily_revenue", 0.0))
	state.daily_expenses = float(data.get("daily_expenses", 0.0))
	state.daily_missed_sales = int(data.get("daily_missed_sales", 0))
	state.last_tick_sales = int(data.get("last_tick_sales", 0))
	state.last_tick_missed_sales = int(data.get("last_tick_missed_sales", 0))
	state.last_tick_revenue = float(data.get("last_tick_revenue", 0.0))

	if state.price_levels.is_empty() and not state.prices.is_empty():
		state._migrate_prices_to_levels()

	state.sync_prices_from_levels()
	return state


func _migrate_prices_to_levels() -> void:
	for raw_good_id in prices:
		var good_id := str(raw_good_id)
		var base_price := DataRegistry.get_good_price(good_id)
		if base_price <= 0.0:
			continue
		var sale_price: float = float(prices.get(good_id, base_price))
		var ratio := sale_price / base_price
		var level := int(round((ratio - DemandFormula.MULTIPLIER_AT_MIN) / 0.15))
		price_levels[good_id] = DemandFormula.clamp_level(level)
