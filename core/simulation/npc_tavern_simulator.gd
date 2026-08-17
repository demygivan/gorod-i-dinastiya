class_name NpcTavernSimulator
extends RefCounted
## Вечерняя трата всех денег NPC в таверне. Без мутаций GameState.


static func derive_rng_seed(base_seed: int, business_id: String, day: int, npc_id: String) -> int:
	return hash("%d:%s:%d:%s:tavern" % [base_seed, business_id, day, npc_id])


static func simulate_tavern_spending(
	tavern: BusinessState,
	npcs: Array[NpcState],
	day: int,
	base_seed: int,
) -> Dictionary:
	var tick_result := DemandTickResult.new()
	var npc_events: Array[NpcPurchaseEvent] = []
	var drained_npc_ids: Array[String] = []

	if tavern == null or npcs.is_empty():
		return {
			"tick_result": tick_result,
			"npc_events": npc_events,
			"drained_npc_ids": drained_npc_ids,
		}

	var drink_goods := _get_drink_goods_sorted_by_price(tavern)

	var sorted_npcs: Array[NpcState] = npcs.duplicate()
	sorted_npcs.sort_custom(_sort_npcs_by_id)

	var stock_plan: Dictionary = {}
	for good_id in tavern.storage:
		stock_plan[str(good_id)] = BusinessEconomy.get_storage_quantity(tavern, str(good_id))

	for npc in sorted_npcs:
		if npc.cash <= 0.0:
			continue

		drained_npc_ids.append(npc.id)
		if drink_goods.is_empty():
			continue

		var events := _spend_npc_at_tavern(
			npc,
			tavern,
			drink_goods,
			day,
			base_seed,
			stock_plan,
		)
		for event in events:
			npc_events.append(event)
			_accumulate_tick_result(tick_result, event)

	return {
		"tick_result": tick_result,
		"npc_events": npc_events,
		"drained_npc_ids": drained_npc_ids,
	}


static func _spend_npc_at_tavern(
	npc: NpcState,
	tavern: BusinessState,
	drink_goods: Array[String],
	day: int,
	base_seed: int,
	stock_plan: Dictionary,
) -> Array[NpcPurchaseEvent]:
	var events: Array[NpcPurchaseEvent] = []
	var remaining_cash := npc.cash

	var rng := RandomNumberGenerator.new()
	rng.seed = derive_rng_seed(base_seed, tavern.id, day, npc.id)

	while remaining_cash > 0.0:
		var affordable := _pick_affordable_drink(tavern, drink_goods, stock_plan, remaining_cash)
		if affordable.is_empty():
			break

		var candidates: Array[String] = affordable.duplicate()
		var good_id := candidates[rng.randi_range(0, candidates.size() - 1)]
		var sale_price := tavern.get_sale_price(good_id)
		var available := int(stock_plan.get(good_id, 0))

		var event := NpcPurchaseEvent.new()
		event.npc_id = npc.id
		event.good_id = good_id
		event.intended_qty = 1
		event.sold_qty = 1
		event.revenue = sale_price
		event.outcome = NpcPurchaseEvent.Outcome.PURCHASED
		remaining_cash -= sale_price
		event.npc_cash_after = remaining_cash
		events.append(event)

		stock_plan[good_id] = available - 1

	return events


static func _get_drink_goods_sorted_by_price(tavern: BusinessState) -> Array[String]:
	var drinks: Array[String] = []
	for good_id in BusinessEconomy.get_sellable_goods_for_business(tavern):
		var good := DataRegistry.get_good(str(good_id))
		if good != null and good.category == "drink":
			drinks.append(str(good_id))

	drinks.sort_custom(func(a: String, b: String) -> bool:
		return tavern.get_sale_price(a) < tavern.get_sale_price(b)
	)
	return drinks


static func _pick_affordable_drink(
	tavern: BusinessState,
	drink_goods: Array[String],
	stock_plan: Dictionary,
	remaining_cash: float,
) -> Array[String]:
	var result: Array[String] = []
	for good_id in drink_goods:
		var sale_price := tavern.get_sale_price(good_id)
		if sale_price <= 0.0 or remaining_cash < sale_price:
			continue
		if int(stock_plan.get(good_id, 0)) <= 0:
			continue
		result.append(good_id)
	return result


static func _accumulate_tick_result(tick_result: DemandTickResult, event: NpcPurchaseEvent) -> void:
	if event.good_id.is_empty():
		return

	if event.outcome == NpcPurchaseEvent.Outcome.PURCHASED:
		tick_result.add_good_result(
			event.good_id,
			event.sold_qty,
			event.intended_qty,
			event.sold_qty,
			event.revenue,
		)


static func _sort_npcs_by_id(a: NpcState, b: NpcState) -> bool:
	return a.id < b.id
