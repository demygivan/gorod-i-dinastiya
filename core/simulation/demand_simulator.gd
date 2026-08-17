class_name DemandSimulator
extends RefCounted
## Фасад дневного спроса. Делегирует именованным NPC.


static func derive_rng_seed(base_seed: int, business_id: String, day: int) -> int:
	return hash("%d:%s:%d" % [base_seed, business_id, day])


static func simulate_daily_demand(
	business: BusinessState,
	npcs: Array[NpcState],
	formula: DemandFormula,
	day: int,
	base_seed: int,
	player_reputation_value: float,
	reputation_formula: ReputationFormula,
) -> Dictionary:
	return NpcDemandSimulator.simulate_daily_demand(
		business,
		npcs,
		formula,
		day,
		base_seed,
		player_reputation_value,
		reputation_formula,
	)
