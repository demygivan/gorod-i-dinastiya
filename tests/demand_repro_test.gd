extends SceneTree
## Headless repro test: одинаковый seed → одинаковый результат спроса NPC.


var _expected: Dictionary = {}


func _initialize() -> void:
	_expected = _run_once()
	var second := _run_once()
	var failures := _compare(_expected, second)
	failures.append_array(_validate_golden(_expected))

	if failures.is_empty():
		print("[demand_repro_test] PASS sales=%d missed=%d revenue=%.0f" % [
			_expected.sales,
			_expected.missed,
			_expected.revenue,
		])
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)


func _run_once() -> Dictionary:
	_reset_state()
	var result := CommandProcessor.execute(
		SimulateDailyDemandCommand.execute,
		["bakery", 1],
	)
	if not result.success:
		push_error(result.error)
		return {"sales": -1, "missed": -1, "revenue": -1.0, "npc_cash": {}}

	var business := GameState.get_business("bakery")
	var npc_cash := {}
	for npc in GameState.get_npcs_sorted():
		npc_cash[npc.id] = npc.cash

	return {
		"sales": business.last_tick_sales,
		"missed": business.last_tick_missed_sales,
		"revenue": business.last_tick_revenue,
		"npc_cash": npc_cash,
	}


func _compare(first: Dictionary, second: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = []
	if first.sales != second.sales:
		failures.append("Repro sales: %d != %d" % [first.sales, second.sales])
	if first.missed != second.missed:
		failures.append("Repro missed: %d != %d" % [first.missed, second.missed])
	if not is_equal_approx(first.revenue, second.revenue):
		failures.append("Repro revenue: %.2f != %.2f" % [first.revenue, second.revenue])
	return failures


func _validate_golden(result: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = []
	if result.sales <= 0:
		failures.append("Expected some sales with 20 NPCs, got %d" % result.sales)
	if result.revenue <= 0.0:
		failures.append("Expected positive revenue, got %.0f" % result.revenue)
	return failures


func _reset_state() -> void:
	var scenario := DataRegistry.get_scenario("default_scenario")

	GameState.businesses.clear()
	GameState.npcs.clear()
	GameState.simulation_seed = 12345
	GameState.demand_formula_id = scenario.demand_formula_id
	GameState.reputation_formula_id = scenario.reputation_formula_id

	GameState.player_reputation = ReputationState.new()
	GameState.player_reputation.owner_id = GameState.DEFAULT_PLAYER_ID
	GameState.player_reputation.value = scenario.starting_player_reputation

	var business := BusinessState.new()
	business.id = "bakery"
	business.type_id = "bakery"
	business.cash = 500.0
	business.storage = {"flour": 10, "bread": 50}
	business.price_levels = {"bread": DemandFormula.DEFAULT_LEVEL}
	business.sync_prices_from_levels()
	GameState.register_business(business)

	for npc in NpcSpawner.create_starting_npcs(scenario, GameState.simulation_seed):
		GameState.register_npc(npc)
