class_name NpcShoppingScheduler
extends RefCounted
## Случайный час похода за покупками для каждого NPC (детерминированно по seed).


static func get_shopping_hour(npc: NpcState, day: int, base_seed: int) -> int:
	var scenario := GameState.get_scenario()
	var hour_start := 10
	var hour_end := 19
	if scenario != null:
		hour_start = scenario.shopping_hour_start
		hour_end = scenario.shopping_hour_end

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s:shopping_hour" % [base_seed, day, npc.id])
	return rng.randi_range(hour_start, hour_end)


static func filter_npcs_for_hour(
	npcs: Array[NpcState],
	day: int,
	base_seed: int,
	hour: int,
) -> Array[NpcState]:
	var result: Array[NpcState] = []
	for npc in npcs:
		if get_shopping_hour(npc, day, base_seed) == hour:
			result.append(npc)
	return result
