class_name NpcDemandProfileGenerator
extends RefCounted
## Назначает каждому NPC профиль потребления: N случайных товаров фиксированного кол-ва.


const GOODS_PER_NPC := 3
const QTY_PER_GOOD := 10


static func assign_profile(npc: NpcState, base_seed: int) -> void:
	npc.demand_goods.clear()

	var pool := _build_goods_pool(npc)
	if pool.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:demand_profile" % [base_seed, npc.id])

	var picks: Array[String] = []
	while picks.size() < mini(GOODS_PER_NPC, pool.size()):
		var good_id := pool[rng.randi_range(0, pool.size() - 1)]
		if picks.has(good_id):
			continue
		picks.append(good_id)

	for good_id in picks:
		npc.demand_goods[good_id] = QTY_PER_GOOD


static func ensure_profile(npc: NpcState, base_seed: int) -> void:
	if npc.demand_goods.is_empty():
		assign_profile(npc, base_seed)


static func _build_goods_pool(npc: NpcState) -> Array[String]:
	var archetype := DataRegistry.get_npc_archetype(npc.archetype_id)
	if archetype != null and not archetype.preferred_goods.is_empty():
		var preferred: Array[String] = []
		for raw_good_id in archetype.preferred_goods:
			var good_id := str(raw_good_id)
			if DataRegistry.get_good(good_id) != null:
				preferred.append(good_id)
		if preferred.size() >= GOODS_PER_NPC:
			return preferred

	var pool: Array[String] = []
	for good in DataRegistry.get_goods():
		pool.append(good.id)
	return pool
