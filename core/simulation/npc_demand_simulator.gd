class_name NpcDemandSimulator
extends RefCounted
## Дневной спрос именованных NPC. Без мутаций GameState.


static func derive_rng_seed(base_seed: int, business_id: String, day: int, npc_id: String) -> int:
	return hash("%d:%s:%d:%s" % [base_seed, business_id, day, npc_id])


static func simulate_daily_demand(
	business: BusinessState,
	npcs: Array[NpcState],
	formula: DemandFormula,
	day: int,
	base_seed: int,
	player_reputation_value: float,
	reputation_formula: ReputationFormula,
) -> Dictionary:
	var tick_result := DemandTickResult.new()
	var npc_events: Array[NpcPurchaseEvent] = []

	if business == null or formula == null or npcs.is_empty():
		return {"tick_result": tick_result, "npc_events": npc_events}

	var sellable := BusinessEconomy.get_sellable_goods_for_business(business)
	if sellable.is_empty():
		return {"tick_result": tick_result, "npc_events": npc_events}

	var sorted_npcs: Array[NpcState] = npcs.duplicate()
	sorted_npcs.sort_custom(_sort_npcs_by_id)

	var stock_plan: Dictionary = {}
	for good_id in business.storage:
		stock_plan[str(good_id)] = BusinessEconomy.get_storage_quantity(business, str(good_id))

	for npc in sorted_npcs:
		var events := _simulate_npc_purchases(
			npc,
			business,
			sellable,
			formula,
			day,
			base_seed,
			stock_plan,
			player_reputation_value,
			reputation_formula,
		)
		for event in events:
			npc_events.append(event)
			_accumulate_tick_result(tick_result, event)

	return {"tick_result": tick_result, "npc_events": npc_events}


static func _simulate_npc_purchases(
	npc: NpcState,
	business: BusinessState,
	sellable_goods: Array[String],
	formula: DemandFormula,
	day: int,
	base_seed: int,
	stock_plan: Dictionary,
	player_reputation_value: float,
	reputation_formula: ReputationFormula,
) -> Array[NpcPurchaseEvent]:
	var events: Array[NpcPurchaseEvent] = []
	var remaining_cash := npc.cash

	var archetype := DataRegistry.get_npc_archetype(npc.archetype_id)
	if archetype == null:
		events.append(NpcPurchaseEvent.skipped(npc.id))
		return events

	if npc.demand_goods.is_empty():
		events.append(NpcPurchaseEvent.skipped(npc.id))
		return events

	var sorted_goods: Array[String] = []
	for raw_good_id in npc.demand_goods:
		sorted_goods.append(str(raw_good_id))
	sorted_goods.sort()

	var rng := RandomNumberGenerator.new()
	rng.seed = derive_rng_seed(base_seed, business.id, day, npc.id)

	for good_id in sorted_goods:
		if remaining_cash <= 0.0:
			break
		if not sellable_goods.has(good_id):
			continue

		var wanted_qty := int(npc.demand_goods.get(good_id, 0))
		if wanted_qty <= 0:
			continue

		var event := _try_purchase_good(
			npc,
			archetype,
			business,
			good_id,
			wanted_qty,
			formula,
			rng,
			remaining_cash,
			stock_plan,
			player_reputation_value,
			reputation_formula,
		)
		if event.outcome == NpcPurchaseEvent.Outcome.PURCHASED:
			remaining_cash = event.npc_cash_after
		events.append(event)

	if events.is_empty():
		events.append(NpcPurchaseEvent.skipped(npc.id))

	return events


static func _try_purchase_good(
	npc: NpcState,
	archetype: NpcArchetypeDefinition,
	business: BusinessState,
	good_id: String,
	wanted_qty: int,
	formula: DemandFormula,
	rng: RandomNumberGenerator,
	remaining_cash: float,
	stock_plan: Dictionary,
	player_reputation_value: float,
	reputation_formula: ReputationFormula,
) -> NpcPurchaseEvent:
	var event := NpcPurchaseEvent.new()
	event.npc_id = npc.id
	event.good_id = good_id
	event.intended_qty = wanted_qty

	var good := DataRegistry.get_good(good_id)
	if good == null:
		event.outcome = NpcPurchaseEvent.Outcome.SKIPPED
		return event

	var sale_price := business.get_sale_price(good_id)
	if sale_price <= 0.0:
		event.outcome = NpcPurchaseEvent.Outcome.SKIPPED
		return event

	if remaining_cash < sale_price:
		event.outcome = NpcPurchaseEvent.Outcome.NO_CASH
		event.npc_cash_after = remaining_cash
		return event

	var level := business.get_price_level(good_id)
	var willingness := DemandFormula.willingness_from_level(
		level,
		archetype.price_sensitivity,
	)
	var reputation_mult := ReputationFormula.demand_multiplier(
		player_reputation_value,
		reputation_formula,
	)
	willingness = clampf(willingness * reputation_mult, 0.0, 1.0)
	if rng.randf() >= willingness:
		event.outcome = NpcPurchaseEvent.Outcome.TOO_EXPENSIVE
		event.npc_cash_after = remaining_cash
		return event

	var max_affordable := int(floor(remaining_cash / sale_price))
	var available := int(stock_plan.get(good_id, 0))
	var buy_qty := mini(wanted_qty, mini(max_affordable, available))

	if buy_qty <= 0:
		if available <= 0:
			event.outcome = NpcPurchaseEvent.Outcome.NO_STOCK
		else:
			event.outcome = NpcPurchaseEvent.Outcome.NO_CASH
		event.npc_cash_after = remaining_cash
		return event

	stock_plan[good_id] = available - buy_qty
	event.sold_qty = buy_qty
	event.revenue = sale_price * float(buy_qty)
	event.outcome = NpcPurchaseEvent.Outcome.PURCHASED
	event.npc_cash_after = remaining_cash - event.revenue
	return event


static func _accumulate_tick_result(tick_result: DemandTickResult, event: NpcPurchaseEvent) -> void:
	if event.good_id.is_empty():
		return

	match event.outcome:
		NpcPurchaseEvent.Outcome.PURCHASED:
			tick_result.add_good_result(
				event.good_id,
				event.sold_qty,
				event.intended_qty,
				event.sold_qty,
				event.revenue,
			)
		NpcPurchaseEvent.Outcome.NO_STOCK:
			tick_result.add_good_result(event.good_id, 1, event.intended_qty, 0, 0.0)
		_:
			pass


static func _sort_npcs_by_id(a: NpcState, b: NpcState) -> bool:
	return a.id < b.id
