class_name ScenarioDefinition
extends Resource
## Статическое определение стартового сценария. Экземпляры — data/scenarios/*.tres.

@export var id: String = ""
@export var name_key: String = ""
@export var starting_cash: float = 0.0
@export var starting_business_type: String = ""
@export var starting_goods: Array[String] = []
@export var simulation_seed: int = 12345
@export var demand_formula_id: String = "default_demand"
@export var starting_player_reputation: float = 50.0
@export var reputation_formula_id: String = "default_reputation"
@export var voting_formula_id: String = "default_voting"
@export var proposed_law_id: String = "trade_tax_reduction"
@export var council_vote_interval_days: int = 7
@export var council_first_vote_day: int = 7
@export var starting_npc_count: int = 20
@export var starting_npc_archetypes: Array[String] = []
@export var npc_starting_cash: float = 100.0
@export var npc_income_per_day: float = 100.0
@export var shopping_hour_start: int = 10
@export var shopping_hour_end: int = 19
@export var tavern_hour: int = 20
@export var npc_leave_home_hour: int = 6
@export var npc_sleep_hour: int = 0
@export var npc_archetype_pool: Array[String] = [
	"peasant",
	"laborer",
	"craftsman",
	"merchant",
	"elder",
	"noble",
]
