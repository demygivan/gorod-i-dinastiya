extends Node
## Headless repro test: одинаковый seed → одинаковый результат голосования совета.


var _expected: Dictionary = {}


func _ready() -> void:
	_expected = _run_once()
	var second := _run_once()
	var failures := _compare(_expected, second)

	if failures.is_empty():
		print("[vote_repro_test] PASS for=%d against=%d passed=%s" % [
			_expected.votes_for,
			_expected.votes_against,
			_expected.passed,
		])
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		get_tree().quit(1)


func _run_once() -> Dictionary:
	_reset_state()
	var result := CommandProcessor.execute(
		RunCouncilVoteCommand.execute,
		["trade_tax_reduction", 7],
	)
	if not result.success:
		push_error(result.error)
		return {"votes_for": -1, "votes_against": -1, "passed": false}

	var vote := GameState.last_vote_result
	return {
		"votes_for": vote.votes_for,
		"votes_against": vote.votes_against,
		"passed": vote.passed,
	}


func _compare(first: Dictionary, second: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = []
	if first.votes_for != second.votes_for:
		failures.append("Repro votes_for: %d != %d" % [first.votes_for, second.votes_for])
	if first.votes_against != second.votes_against:
		failures.append("Repro votes_against: %d != %d" % [first.votes_against, second.votes_against])
	if first.passed != second.passed:
		failures.append("Repro passed: %s != %s" % [first.passed, second.passed])
	return failures


func _reset_state() -> void:
	var scenario := DataRegistry.get_scenario("default_scenario")

	GameState.businesses.clear()
	GameState.npcs.clear()
	GameState.laws.clear()
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
	GameState.player_reputation.value = scenario.starting_player_reputation

	var business := BusinessState.new()
	business.id = "bakery"
	business.type_id = "bakery"
	business.owner_id = GameState.DEFAULT_PLAYER_ID
	business.cash = 500.0
	GameState.register_business(business)

	for npc in NpcSpawner.create_starting_npcs(scenario, GameState.simulation_seed):
		GameState.register_npc(npc)
