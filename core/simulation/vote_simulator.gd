class_name VoteSimulator
extends RefCounted
## Чистая симуляция голосования NPC. Без мутаций GameState.


static func derive_rng_seed(base_seed: int, law_id: String, vote_day: int, npc_id: String) -> int:
	return hash("%d:%s:%d:%s" % [base_seed, law_id, vote_day, npc_id])


static func simulate_vote(
	law_id: String,
	npcs: Array[NpcState],
	formula: VotingFormula,
	vote_day: int,
	base_seed: int,
	player_business_id: String,
) -> VoteResult:
	var result := VoteResult.new()
	result.day = vote_day
	result.law_id = law_id

	if formula == null or npcs.is_empty():
		return result

	var sorted_npcs: Array[NpcState] = npcs.duplicate()
	sorted_npcs.sort_custom(func(a: NpcState, b: NpcState) -> bool: return a.id < b.id)

	for npc in sorted_npcs:
		var yes_score := _compute_yes_score(npc, formula, player_business_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = derive_rng_seed(base_seed, law_id, vote_day, npc.id)
		var vote_yes := rng.randf() < yes_score
		result.npc_votes[npc.id] = vote_yes
		if vote_yes:
			result.votes_for += 1
		else:
			result.votes_against += 1

	var total := result.votes_for + result.votes_against
	result.passed = total > 0 and float(result.votes_for) / float(total) > formula.pass_threshold
	return result


static func _compute_yes_score(
	npc: NpcState,
	formula: VotingFormula,
	player_business_id: String,
) -> float:
	var archetype := DataRegistry.get_npc_archetype(npc.archetype_id)
	var alignment_term := 0.0
	if archetype != null:
		alignment_term = archetype.political_alignment * formula.alignment_weight

	var relationship_term := ((npc.relationship_to_player - 50.0) / 50.0) * formula.relationship_weight

	var self_interest := 0.0
	if npc.last_purchase_business_id == player_business_id \
			or npc.relationship_to_player >= formula.relationship_self_interest_min:
		self_interest = formula.self_interest_weight

	return clampf(
		formula.base_yes_score
		+ alignment_term
		+ relationship_term
		+ self_interest
		+ npc.campaign_vote_bonus,
		0.0,
		1.0,
	)
