class_name SimulateTavernSpendingCommand
extends RefCounted
## В 20:00 NPC тратят все оставшиеся деньги в таверне.


static func execute(business_id: String, day: int) -> CommandResult:
	var tavern := GameState.get_business(business_id)
	var validation := _validate(tavern, day)
	if not validation.success:
		return validation

	var npcs := GameState.get_npcs_sorted()
	var simulation := NpcTavernSimulator.simulate_tavern_spending(
		tavern,
		npcs,
		day,
		GameState.simulation_seed,
	)

	var tick_result: DemandTickResult = simulation["tick_result"]
	var npc_events: Array = simulation["npc_events"]
	var drained_npc_ids: Array = simulation["drained_npc_ids"]

	SimulateDailyDemandCommand.apply_sales_to_business(tavern, tick_result)
	SimulateDailyDemandCommand.apply_npc_purchase_events(business_id, day, npc_events)
	_drain_remaining_cash(drained_npc_ids)

	tavern.last_tick_sales = tick_result.total_sales
	tavern.last_tick_missed_sales = tick_result.total_missed
	tavern.last_tick_revenue = tick_result.total_revenue

	EventBus.business_demand_tick_completed.emit(
		business_id,
		tick_result.total_sales,
		tick_result.total_missed,
		tick_result.total_revenue,
		day,
	)
	EventBus.business_cash_changed.emit(business_id, tavern.cash)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(tavern: BusinessState, day: int) -> CommandResult:
	if tavern == null:
		return CommandResult.fail("Таверна не найдена")
	if tavern.type_id != "tavern":
		return CommandResult.fail("Предприятие не является таверной")
	if day < 1:
		return CommandResult.fail("Некорректный день симуляции")
	if GameState.npcs.is_empty():
		return CommandResult.fail("В городе нет NPC")
	return CommandResult.ok()


static func _drain_remaining_cash(drained_npc_ids: Array) -> void:
	for raw_npc_id in drained_npc_ids:
		var npc := GameState.get_npc(str(raw_npc_id))
		if npc == null:
			continue
		if is_equal_approx(npc.cash, 0.0):
			continue
		npc.cash = 0.0
		npc.last_purchase_note = "tavern_drained"
		EventBus.npc_cash_changed.emit(npc.id, npc.cash)
