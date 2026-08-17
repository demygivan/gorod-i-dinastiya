extends Node
## Headless round-trip test for SaveManager.


const SLOT_NAME := "repro_save_test"
const BUSINESS_ID := "bakery"


func _ready() -> void:
	await get_tree().process_frame

	var failures := PackedStringArray()
	failures.append_array(_run_round_trip())
	failures.append_array(_run_version_mismatch())

	if failures.is_empty():
		print("[save_repro_test] PASS")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		get_tree().quit(1)


func _run_round_trip() -> PackedStringArray:
	_seed_known_state()

	var save_result := SaveManager.save_game(SLOT_NAME)
	if not save_result.success:
		return PackedStringArray(["Save failed: %s" % save_result.error])

	var expected := _capture_state()
	_corrupt_state()

	var load_result := SaveManager.load_game(SLOT_NAME)
	if not load_result.success:
		return PackedStringArray(["Load failed: %s" % load_result.error])

	return _compare_state(expected)


func _run_version_mismatch() -> PackedStringArray:
	var path := SaveManager.SAVE_DIR.path_join("%s.json" % SLOT_NAME)
	if not FileAccess.file_exists(path):
		return PackedStringArray(["Version test: save file missing"])

	var file := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	data["save_version"] = 1

	var corrupt_path := SaveManager.SAVE_DIR.path_join("corrupt_version.json")
	var out := FileAccess.open(corrupt_path, FileAccess.WRITE)
	out.store_string(JSON.stringify(data, "\t"))
	out.close()

	var cash_before := GameState.get_business(BUSINESS_ID).cash
	var result := SaveManager.load_game("corrupt_version")
	if result.success:
		return PackedStringArray(["Version mismatch should fail"])

	if GameState.get_business(BUSINESS_ID).cash != cash_before:
		return PackedStringArray(["Version mismatch must not mutate GameState"])

	return PackedStringArray()


func _seed_known_state() -> void:
	var scenario := DataRegistry.get_scenario("default_scenario")
	GameState.businesses.clear()
	GameState.npcs.clear()
	GameState.laws.clear()
	GameState.scenario_id = scenario.id
	GameState.simulation_seed = 12345
	GameState.demand_formula_id = scenario.demand_formula_id
	GameState.reputation_formula_id = scenario.reputation_formula_id
	GameState.voting_formula_id = scenario.voting_formula_id
	GameState.proposed_law_id = scenario.proposed_law_id
	GameState.council_vote_interval_days = scenario.council_vote_interval_days
	GameState.council_first_vote_day = scenario.council_first_vote_day
	GameState.last_vote_day = 0
	GameState.last_vote_result = null

	GameState.player_reputation = ReputationState.new()
	GameState.player_reputation.owner_id = GameState.DEFAULT_PLAYER_ID
	GameState.player_reputation.value = 55.0

	var business := BusinessState.new()
	business.id = BUSINESS_ID
	business.type_id = BUSINESS_ID
	business.owner_id = GameState.DEFAULT_PLAYER_ID
	business.cash = 333.0
	business.storage = {"flour": 10, "bread": 40}
	business.price_levels = {"bread": 4}
	business.sync_prices_from_levels()
	GameState.register_business(business)

	for npc in NpcSpawner.create_starting_npcs(scenario, GameState.simulation_seed):
		GameState.register_npc(npc)

	var first_npc := GameState.get_npcs_sorted()[0]
	first_npc.cash = 7.0

	SimulationClock.from_dict({
		"day": 5,
		"hour": 10,
		"minute": 15,
		"paused": true,
		"speed_multiplier": 2,
		"minute_accumulator": 0.25,
	})

	FinanceHistory.from_dict({
		"live": {
			BUSINESS_ID: {
				"business_id": BUSINESS_ID,
				"game_day": 5,
				"cash": 333.0,
				"storage": {"flour": 10, "bread": 40},
				"price_levels": {"bread": 4},
				"prices": {"bread": 10.0},
				"daily_revenue": 50.0,
				"daily_expenses": 12.0,
				"daily_sales": 3,
				"daily_missed_sales": 1,
				"player_reputation": 55.0,
				"player_reputation_demand_mult": 1.05,
			},
		},
		"history": {
			BUSINESS_ID: [
				{
					"day": 4,
					"revenue": 80.0,
					"expenses": 12.0,
					"profit": 68.0,
					"sales_count": 5,
					"missed_sales": 0,
					"cash_end_of_day": 300.0,
				},
			],
		},
	})


func _corrupt_state() -> void:
	GameState.get_business(BUSINESS_ID).cash = 0.0
	SimulationClock.day = 1
	GameState.npcs.clear()


func _capture_state() -> Dictionary:
	var business := GameState.get_business(BUSINESS_ID)
	var first_npc := GameState.get_npcs_sorted()[0]
	var live := FinanceHistory.get_live(BUSINESS_ID)
	var history := FinanceHistory.get_history(BUSINESS_ID)
	return {
		"cash": business.cash,
		"npc_cash": first_npc.cash,
		"day": SimulationClock.day,
		"hour": SimulationClock.hour,
		"minute": SimulationClock.minute,
		"paused": SimulationClock.paused,
		"speed": SimulationClock.speed_multiplier,
		"live_cash": live.cash if live != null else -1.0,
		"history_count": history.size(),
		"scenario_id": GameState.scenario_id,
		"reputation": GameState.player_reputation.value,
	}


func _compare_state(expected: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = []
	var business := GameState.get_business(BUSINESS_ID)
	var first_npc := GameState.get_npcs_sorted()[0]
	var live := FinanceHistory.get_live(BUSINESS_ID)
	var history := FinanceHistory.get_history(BUSINESS_ID)

	if business.cash != expected.cash:
		failures.append("cash: %.0f != %.0f" % [business.cash, expected.cash])
	if first_npc.cash != expected.npc_cash:
		failures.append("npc cash: %.0f != %.0f" % [first_npc.cash, expected.npc_cash])
	if SimulationClock.day != expected.day:
		failures.append("day: %d != %d" % [SimulationClock.day, expected.day])
	if SimulationClock.hour != expected.hour:
		failures.append("hour mismatch")
	if SimulationClock.minute != expected.minute:
		failures.append("minute mismatch")
	if SimulationClock.paused != expected.paused:
		failures.append("paused mismatch")
	if SimulationClock.speed_multiplier != expected.speed:
		failures.append("speed mismatch")
	if live == null or live.cash != expected.live_cash:
		failures.append("finance live cash mismatch")
	if history.size() != expected.history_count:
		failures.append("history count: %d != %d" % [history.size(), expected.history_count])
	if GameState.scenario_id != expected.scenario_id:
		failures.append("scenario_id mismatch")
	if GameState.player_reputation.value != expected.reputation:
		failures.append("reputation mismatch")

	return failures
