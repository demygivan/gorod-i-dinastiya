extends Node
## Read-модель финансов для debug UI. Слушает EventBus, не мутирует GameState.


signal finance_live_updated(business_id: String)
signal finance_history_updated(business_id: String)

const MAX_HISTORY_DAYS := 30

var _live: Dictionary = {}    ## business_id -> FinanceLiveSnapshot
var _history: Dictionary = {} ## business_id -> Array[DayFinanceRecord]


func _ready() -> void:
	call_deferred("_bootstrap_from_game_state")
	_connect_event_bus()


func get_live(business_id: String) -> FinanceLiveSnapshot:
	return _live.get(business_id, null)


func get_history(business_id: String) -> Array[DayFinanceRecord]:
	if not _history.has(business_id):
		return []
	var result: Array[DayFinanceRecord] = []
	for entry in _history[business_id]:
		if entry is DayFinanceRecord:
			result.append(entry)
	return result


func record_day(business_id: String, record: DayFinanceRecord) -> void:
	if not _history.has(business_id):
		_history[business_id] = []

	var entries: Array = _history[business_id]
	entries.append(record)
	while entries.size() > MAX_HISTORY_DAYS:
		entries.pop_front()

	finance_history_updated.emit(business_id)


func to_dict() -> Dictionary:
	var live_payload := {}
	for business_id in _live:
		live_payload[str(business_id)] = _live_snapshot_to_dict(_live[business_id])

	var history_payload := {}
	for business_id in _history:
		var records: Array = []
		for entry in _history[business_id]:
			if entry is DayFinanceRecord:
				records.append(entry.to_dict())
		history_payload[str(business_id)] = records

	return {
		"live": live_payload,
		"history": history_payload,
	}


func from_dict(data: Dictionary) -> SaveResult:
	_live.clear()
	_history.clear()

	var raw_live: Dictionary = data.get("live", {})
	for business_id in raw_live:
		var snapshot := _live_snapshot_from_dict(raw_live[business_id])
		if snapshot == null:
			return SaveResult.fail("FinanceHistory: invalid live snapshot for %s" % str(business_id))
		_live[str(business_id)] = snapshot

	var raw_history: Dictionary = data.get("history", {})
	for business_id in raw_history:
		var entries: Array = []
		for raw_record in raw_history[business_id]:
			if raw_record is Dictionary:
				entries.append(DayFinanceRecord.from_dict(raw_record))
		_history[str(business_id)] = entries

	for business_id in _live:
		finance_live_updated.emit(str(business_id))
	for business_id in _history:
		finance_history_updated.emit(str(business_id))

	return SaveResult.ok()


func _bootstrap_from_game_state() -> void:
	_sync_player_reputation_from_game_state()
	for business_id in GameState.businesses:
		var business: BusinessState = GameState.businesses[business_id]
		_live[str(business_id)] = _snapshot_from_business(business)
		finance_live_updated.emit(str(business_id))


func _connect_event_bus() -> void:
	EventBus.business_cash_changed.connect(_on_business_cash_changed)
	EventBus.business_storage_changed.connect(_on_business_storage_changed)
	EventBus.business_price_level_changed.connect(_on_business_price_level_changed)
	EventBus.business_demand_tick_completed.connect(_on_business_demand_tick_completed)
	EventBus.business_daily_costs_applied.connect(_on_business_daily_costs_applied)
	EventBus.business_day_ended.connect(_on_business_day_ended)
	EventBus.reputation_changed.connect(_on_reputation_changed)


func _on_business_cash_changed(business_id: String, new_cash: float) -> void:
	var live := _ensure_live(business_id)
	if live == null:
		return
	live.cash = new_cash
	finance_live_updated.emit(business_id)


func _on_business_storage_changed(
	business_id: String,
	good_id: String,
	new_quantity: int,
) -> void:
	var live := _ensure_live(business_id)
	if live == null:
		return
	if new_quantity <= 0:
		live.storage.erase(good_id)
	else:
		live.storage[good_id] = new_quantity
	finance_live_updated.emit(business_id)


func _on_business_price_level_changed(
	business_id: String,
	good_id: String,
	level: int,
) -> void:
	var live := _ensure_live(business_id)
	if live == null:
		return
	live.price_levels[good_id] = level
	live.prices[good_id] = DemandFormula.compute_sale_price(
		DataRegistry.get_good_price(good_id),
		level,
	)
	finance_live_updated.emit(business_id)


func _on_business_demand_tick_completed(
	business_id: String,
	sales_count: int,
	missed_sales_count: int,
	revenue: float,
	day: int,
) -> void:
	var live := _ensure_live(business_id)
	if live == null:
		return
	live.game_day = day
	live.daily_sales += sales_count
	live.daily_missed_sales += missed_sales_count
	live.daily_revenue += revenue
	finance_live_updated.emit(business_id)


func _on_business_daily_costs_applied(business_id: String, amount: float) -> void:
	var live := _ensure_live(business_id)
	if live == null:
		return
	live.daily_expenses += amount
	finance_live_updated.emit(business_id)


func _on_business_day_ended(business_id: String, _record: DayFinanceRecord) -> void:
	var live := _ensure_live(business_id)
	if live == null:
		return
	live.daily_revenue = 0.0
	live.daily_expenses = 0.0
	live.daily_sales = 0
	live.daily_missed_sales = 0
	live.game_day = SimulationClock.day
	finance_live_updated.emit(business_id)


func _on_reputation_changed(_owner_id: String, new_value: float, _delta_applied: float) -> void:
	_apply_player_reputation_to_live(new_value)
	for business_id in _live:
		finance_live_updated.emit(str(business_id))


func _sync_player_reputation_from_game_state() -> void:
	if GameState.player_reputation == null:
		return
	var formula := GameState.get_reputation_formula()
	var value := GameState.player_reputation.clamped_value(formula)
	_apply_player_reputation_to_live(value)


func _apply_player_reputation_to_live(value: float) -> void:
	var formula := GameState.get_reputation_formula()
	var demand_mult := ReputationFormula.demand_multiplier(value, formula)
	for business_id in _live:
		var live: FinanceLiveSnapshot = _live[business_id]
		live.player_reputation = value
		live.player_reputation_demand_mult = demand_mult


func _ensure_live(business_id: String) -> FinanceLiveSnapshot:
	if _live.has(business_id):
		return _live[business_id]

	var business := GameState.get_business(business_id)
	if business == null:
		return null

	var snapshot := _snapshot_from_business(business)
	_live[business_id] = snapshot
	return snapshot


func _snapshot_from_business(business: BusinessState) -> FinanceLiveSnapshot:
	var live := FinanceLiveSnapshot.new()
	live.business_id = business.id
	live.game_day = SimulationClock.day
	live.cash = business.cash
	live.storage = business.storage.duplicate()
	live.price_levels = business.price_levels.duplicate()
	live.prices = business.prices.duplicate()
	live.daily_revenue = business.daily_revenue
	live.daily_expenses = business.daily_expenses
	live.daily_sales = business.last_tick_sales
	live.daily_missed_sales = business.daily_missed_sales
	if GameState.player_reputation != null:
		var formula := GameState.get_reputation_formula()
		live.player_reputation = GameState.player_reputation.clamped_value(formula)
		live.player_reputation_demand_mult = ReputationFormula.demand_multiplier(
			live.player_reputation,
			formula,
		)
	return live


func _live_snapshot_to_dict(live: FinanceLiveSnapshot) -> Dictionary:
	return {
		"business_id": live.business_id,
		"game_day": live.game_day,
		"cash": live.cash,
		"storage": live.storage.duplicate(),
		"price_levels": live.price_levels.duplicate(),
		"prices": live.prices.duplicate(),
		"daily_revenue": live.daily_revenue,
		"daily_expenses": live.daily_expenses,
		"daily_sales": live.daily_sales,
		"daily_missed_sales": live.daily_missed_sales,
		"player_reputation": live.player_reputation,
		"player_reputation_demand_mult": live.player_reputation_demand_mult,
	}


func _live_snapshot_from_dict(data: Dictionary) -> FinanceLiveSnapshot:
	if data.is_empty():
		return null

	var live := FinanceLiveSnapshot.new()
	live.business_id = str(data.get("business_id", ""))
	live.game_day = int(data.get("game_day", 1))
	live.cash = float(data.get("cash", 0.0))
	live.storage = data.get("storage", {}).duplicate()
	live.price_levels = data.get("price_levels", {}).duplicate()
	live.prices = data.get("prices", {}).duplicate()
	live.daily_revenue = float(data.get("daily_revenue", 0.0))
	live.daily_expenses = float(data.get("daily_expenses", 0.0))
	live.daily_sales = int(data.get("daily_sales", 0))
	live.daily_missed_sales = int(data.get("daily_missed_sales", 0))
	live.player_reputation = float(data.get("player_reputation", 50.0))
	live.player_reputation_demand_mult = float(data.get("player_reputation_demand_mult", 1.0))
	return live
