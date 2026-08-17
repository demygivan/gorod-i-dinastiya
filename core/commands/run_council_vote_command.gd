class_name RunCouncilVoteCommand
extends RefCounted
## Голосование совета по одному закону. Детерминировано при одинаковом seed.


static func execute(law_id: String, vote_day: int) -> CommandResult:
	var definition := DataRegistry.get_law(law_id)
	if definition == null:
		return CommandResult.fail("Закон \"%s\" не найден" % law_id)

	var formula := GameState.get_voting_formula()
	if formula == null:
		return CommandResult.fail("Формула голосования не найдена")

	var player_business_id := _get_player_business_id()
	var vote_result := VoteSimulator.simulate_vote(
		law_id,
		GameState.get_npcs_sorted(),
		formula,
		vote_day,
		GameState.simulation_seed,
		player_business_id,
	)

	_reset_campaign_bonuses()

	if vote_result.passed:
		var law_state := LawState.activate(definition, vote_day)
		GameState.laws[law_id] = law_state
		EventBus.law_activated.emit(law_id, vote_day, law_state.expires_day)

	GameState.last_vote_day = vote_day
	GameState.last_vote_result = vote_result

	EventBus.council_vote_completed.emit(
		law_id,
		vote_result.passed,
		vote_result.votes_for,
		vote_result.votes_against,
		vote_day,
	)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _get_player_business_id() -> String:
	for business_id in GameState.businesses:
		var business: BusinessState = GameState.businesses[business_id]
		if business.owner_id == GameState.DEFAULT_PLAYER_ID:
			return str(business_id)
	return "bakery"


static func _reset_campaign_bonuses() -> void:
	for npc in GameState.get_npcs_sorted():
		npc.campaign_vote_bonus = 0.0
