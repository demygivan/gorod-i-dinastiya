class_name NpcSpawner
extends RefCounted
## Создание стартовых NPC из сценария.


static func create_starting_npcs(
	scenario: ScenarioDefinition,
	base_seed: int,
) -> Array[NpcState]:
	var result: Array[NpcState] = []
	if scenario == null or scenario.starting_npc_count <= 0:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:npc_spawn" % base_seed)

	for index in scenario.starting_npc_count:
		var archetype_id := _resolve_archetype_id(scenario, index, rng)
		var archetype := DataRegistry.get_npc_archetype(archetype_id)
		if archetype == null:
			push_warning("NpcSpawner: unknown archetype \"%s\"" % archetype_id)
			continue

		var npc := NpcState.new()
		npc.id = "npc_%03d" % (index + 1)
		npc.archetype_id = archetype_id
		npc.cash = scenario.npc_starting_cash
		npc.relationship_to_player = 50.0
		npc.reputation_opinion = 50.0
		NpcDemandProfileGenerator.assign_profile(npc, base_seed)
		result.append(npc)

	return result


static func _resolve_archetype_id(
	scenario: ScenarioDefinition,
	index: int,
	rng: RandomNumberGenerator,
) -> String:
	if index < scenario.starting_npc_archetypes.size():
		return str(scenario.starting_npc_archetypes[index])

	if scenario.npc_archetype_pool.is_empty():
		return "peasant"

	var pool_index := rng.randi_range(0, scenario.npc_archetype_pool.size() - 1)
	return str(scenario.npc_archetype_pool[pool_index])
