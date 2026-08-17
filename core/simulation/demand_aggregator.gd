class_name DemandAggregator
extends RefCounted
## Агрегация городского спроса из профилей NPC. Без мутаций.


static func aggregate_city_demand(npcs: Array[NpcState]) -> Dictionary:
	var totals := {}
	for npc in npcs:
		for raw_good_id in npc.demand_goods:
			var good_id := str(raw_good_id)
			var qty: int = int(npc.demand_goods.get(good_id, 0))
			if qty <= 0:
				continue
			totals[good_id] = int(totals.get(good_id, 0)) + qty
	return totals


static func get_sorted_demand_entries(npcs: Array[NpcState]) -> Array[Dictionary]:
	var totals := aggregate_city_demand(npcs)
	var entries: Array[Dictionary] = []

	for good_id in totals:
		entries.append({
			"good_id": str(good_id),
			"quantity": int(totals[good_id]),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return DataRegistry.get_good_name(a.good_id) < DataRegistry.get_good_name(b.good_id)
	)
	return entries
