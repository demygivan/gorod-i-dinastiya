class_name SimulateDailyDemandCommand
extends RefCounted
## Дневной спрос именованных NPC → продажи / упущенные продажи.


static func execute(business_id: String, day: int, shopping_hour: int = -1) -> CommandResult:
	var business := GameState.get_business(business_id)
	var validation := _validate(business, day)
	if not validation.success:
		return validation

	var formula := GameState.get_demand_formula()
	var reputation_formula := GameState.get_reputation_formula()
	var player_reputation_value := 50.0
	if GameState.player_reputation != null and reputation_formula != null:
		player_reputation_value = GameState.player_reputation.clamped_value(reputation_formula)

	var npcs := GameState.get_npcs_sorted()
	if shopping_hour >= 0:
		npcs = NpcShoppingScheduler.filter_npcs_for_hour(
			npcs,
			day,
			GameState.simulation_seed,
			shopping_hour,
		)
	if npcs.is_empty():
		return CommandResult.ok()

	var simulation := DemandSimulator.simulate_daily_demand(
		business,
		npcs,
		formula,
		day,
		GameState.simulation_seed,
		player_reputation_value,
		reputation_formula,
	)

	var tick_result: DemandTickResult = simulation["tick_result"]
	var npc_events: Array = simulation["npc_events"]

	apply_sales_to_business(business, tick_result)
	apply_npc_purchase_events(business_id, day, npc_events)

	for npc in npcs:
		EventBus.npc_shopping_visit.emit(npc.id, business_id)

	business.last_tick_sales = tick_result.total_sales
	business.last_tick_missed_sales = tick_result.total_missed
	business.last_tick_revenue = tick_result.total_revenue
	business.daily_missed_sales += tick_result.total_missed

	EventBus.business_demand_tick_completed.emit(
		business_id,
		tick_result.total_sales,
		tick_result.total_missed,
		tick_result.total_revenue,
		day,
	)
	EventBus.business_cash_changed.emit(business_id, business.cash)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(business: BusinessState, day: int) -> CommandResult:
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if day < 1:
		return CommandResult.fail("Некорректный день симуляции")
	if GameState.get_demand_formula() == null:
		return CommandResult.fail("Формула спроса не найдена")
	if GameState.npcs.is_empty():
		return CommandResult.fail("В городе нет NPC")
	return CommandResult.ok()


static func apply_sales_to_business(business: BusinessState, result: DemandTickResult) -> void:
	for raw_good_id in result.sales_by_good:
		var good_id := str(raw_good_id)
		var sold_qty: int = int(result.sales_by_good[good_id])
		if sold_qty <= 0:
			continue

		var revenue: float = float(result.revenue_by_good.get(good_id, 0.0))
		var new_quantity := BusinessEconomy.get_storage_quantity(business, good_id) - sold_qty

		if new_quantity <= 0:
			business.storage.erase(good_id)
		else:
			business.storage[good_id] = new_quantity

		business.cash += revenue
		business.daily_revenue += revenue

		EventBus.business_storage_changed.emit(
			business.id,
			good_id,
			maxi(new_quantity, 0),
		)


static func apply_npc_purchase_events(
	business_id: String,
	day: int,
	npc_events: Array,
) -> void:
	var cash_updated := {}

	for raw_event in npc_events:
		if not raw_event is NpcPurchaseEvent:
			continue
		var event: NpcPurchaseEvent = raw_event
		var npc := GameState.get_npc(event.npc_id)
		if npc == null:
			continue

		if event.outcome == NpcPurchaseEvent.Outcome.PURCHASED:
			npc.cash = event.npc_cash_after
			cash_updated[npc.id] = true
			npc.last_purchase_day = day
			npc.last_purchase_good_id = event.good_id
			npc.last_purchase_business_id = business_id
			npc.last_purchase_success = true
			npc.last_purchase_note = "purchased"
		elif event.outcome == NpcPurchaseEvent.Outcome.NO_STOCK:
			npc.last_purchase_day = day
			npc.last_purchase_good_id = event.good_id
			npc.last_purchase_business_id = business_id
			npc.last_purchase_success = false
			npc.last_purchase_note = "no_stock"
		elif event.outcome == NpcPurchaseEvent.Outcome.NO_CASH:
			npc.last_purchase_note = "no_cash"
		elif event.outcome == NpcPurchaseEvent.Outcome.TOO_EXPENSIVE:
			npc.last_purchase_note = "too_expensive"

		if event.outcome != NpcPurchaseEvent.Outcome.SKIPPED:
			EventBus.npc_purchase_recorded.emit(
				npc.id,
				business_id,
				event.good_id,
				event.outcome,
				day,
			)

	for npc_id in cash_updated:
		var npc := GameState.get_npc(str(npc_id))
		if npc != null:
			EventBus.npc_cash_changed.emit(npc.id, npc.cash)
