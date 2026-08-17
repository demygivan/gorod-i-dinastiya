extends Node
## Authoritative state симуляции. UI и сцены только читают, мутации — через команды.

const SAVE_VERSION := 9
const DEFAULT_PLAYER_ID := "owner_1"
const DEFAULT_CHARACTER_ID := "hero_1"
const DEFAULT_SCENARIO_ID := "default_scenario"
const TAVERN_OWNER_ID := "owner_tavern"
const TAVERN_STARTING_CASH := 250.0

var businesses: Dictionary = {}  ## business_id (String) -> BusinessState
var npcs: Dictionary = {}        ## npc_id (String) -> NpcState
var characters: Dictionary = {}  ## character_id (String) -> CharacterState
var laws: Dictionary = {}        ## law_id (String) -> LawState
var player_reputation: ReputationState
var scenario_id: String = ""
var simulation_seed: int = 0
var demand_formula_id: String = ""
var reputation_formula_id: String = ""
var voting_formula_id: String = ""
var proposed_law_id: String = ""
var council_vote_interval_days: int = 7
var council_first_vote_day: int = 7
var last_vote_day: int = 0
var last_vote_result: VoteResult = null

var _seeded := false


func _ready() -> void:
	if not _seeded and businesses.is_empty():
		_seed_demo()


func get_business(id: String) -> BusinessState:
	return businesses.get(id, null)


func get_npc(id: String) -> NpcState:
	return npcs.get(id, null)


func get_population() -> int:
	return npcs.size()


func get_npcs_sorted() -> Array[NpcState]:
	var result: Array[NpcState] = []
	for npc_id in npcs:
		result.append(npcs[npc_id])
	result.sort_custom(func(a: NpcState, b: NpcState) -> bool: return a.id < b.id)
	return result


func get_scenario() -> ScenarioDefinition:
	var id := scenario_id if not scenario_id.is_empty() else DEFAULT_SCENARIO_ID
	return DataRegistry.get_scenario(id)


func register_business(data: BusinessState) -> void:
	businesses[data.id] = data


func register_npc(data: NpcState) -> void:
	npcs[data.id] = data


func get_character(id: String) -> CharacterState:
	return characters.get(id, null)


func get_player_character() -> CharacterState:
	return get_character(DEFAULT_CHARACTER_ID)


func get_characters_sorted() -> Array[CharacterState]:
	var result: Array[CharacterState] = []
	for character_id in characters:
		result.append(characters[character_id])
	result.sort_custom(func(a: CharacterState, b: CharacterState) -> bool: return a.id < b.id)
	return result


func register_character(data: CharacterState) -> void:
	characters[data.id] = data


func get_demand_formula() -> DemandFormula:
	return DataRegistry.get_demand_formula(demand_formula_id)


func get_reputation_formula() -> ReputationFormula:
	return DataRegistry.get_reputation_formula(reputation_formula_id)


func get_voting_formula() -> VotingFormula:
	return DataRegistry.get_voting_formula(voting_formula_id)


func get_law_state(law_id: String) -> LawState:
	return laws.get(law_id, null)


func to_dict() -> Dictionary:
	var serialized_businesses := {}
	for business_id in businesses:
		var business: BusinessState = businesses[business_id]
		serialized_businesses[business_id] = business.to_dict()

	var serialized_npcs := {}
	for npc_id in npcs:
		var npc: NpcState = npcs[npc_id]
		serialized_npcs[npc_id] = npc.to_dict()

	var serialized_characters := {}
	for character_id in characters:
		var character: CharacterState = characters[character_id]
		serialized_characters[character_id] = character.to_dict()

	var serialized_laws := {}
	for law_id in laws:
		var law: LawState = laws[law_id]
		serialized_laws[law_id] = law.to_dict()

	var vote_payload: Dictionary = {}
	if last_vote_result != null:
		vote_payload = last_vote_result.to_dict()

	return {
		"simulation_seed": simulation_seed,
		"demand_formula_id": demand_formula_id,
		"reputation_formula_id": reputation_formula_id,
		"voting_formula_id": voting_formula_id,
		"proposed_law_id": proposed_law_id,
		"council_vote_interval_days": council_vote_interval_days,
		"council_first_vote_day": council_first_vote_day,
		"last_vote_day": last_vote_day,
		"player_reputation": player_reputation.to_dict() if player_reputation != null else {},
		"businesses": serialized_businesses,
		"npcs": serialized_npcs,
		"characters": serialized_characters,
		"laws": serialized_laws,
		"last_vote_result": vote_payload,
	}


func from_dict(data: Dictionary) -> SaveResult:
	if data.is_empty():
		return SaveResult.fail("GameState: empty save data")

	simulation_seed = int(data.get("simulation_seed", 0))
	demand_formula_id = str(data.get("demand_formula_id", ""))
	reputation_formula_id = str(data.get("reputation_formula_id", ""))
	voting_formula_id = str(data.get("voting_formula_id", ""))
	proposed_law_id = str(data.get("proposed_law_id", ""))
	council_vote_interval_days = int(data.get("council_vote_interval_days", 7))
	council_first_vote_day = int(data.get("council_first_vote_day", 7))
	last_vote_day = int(data.get("last_vote_day", 0))

	var raw_reputation: Dictionary = data.get("player_reputation", {})
	if raw_reputation.is_empty():
		player_reputation = null
	else:
		player_reputation = ReputationState.from_dict(raw_reputation)

	businesses.clear()
	var raw_businesses: Dictionary = data.get("businesses", {})
	for business_id in raw_businesses:
		var business := BusinessState.from_dict(raw_businesses[business_id])
		if business.id.is_empty():
			return SaveResult.fail("GameState: business with empty id in save")
		register_business(business)

	npcs.clear()
	var raw_npcs: Dictionary = data.get("npcs", {})
	for npc_id in raw_npcs:
		var npc := NpcState.from_dict(raw_npcs[npc_id])
		if npc.id.is_empty():
			return SaveResult.fail("GameState: NPC with empty id in save")
		register_npc(npc)

	characters.clear()
	var raw_characters: Dictionary = data.get("characters", {})
	for character_id in raw_characters:
		var character := CharacterState.from_dict(raw_characters[character_id])
		if character.id.is_empty():
			return SaveResult.fail("GameState: character with empty id in save")
		register_character(character)
	_ensure_player_character()

	laws.clear()
	var raw_laws: Dictionary = data.get("laws", {})
	for law_id in raw_laws:
		laws[str(law_id)] = LawState.from_dict(raw_laws[law_id])

	var raw_vote: Dictionary = data.get("last_vote_result", {})
	last_vote_result = VoteResult.from_dict(raw_vote)
	_ensure_npc_demand_profiles()
	_seeded = true
	return SaveResult.ok()


func _ensure_npc_demand_profiles() -> void:
	for npc in get_npcs_sorted():
		NpcDemandProfileGenerator.ensure_profile(npc, simulation_seed)


func _ensure_player_character() -> void:
	if get_character(DEFAULT_CHARACTER_ID) != null:
		return
	var hero := CharacterState.new()
	hero.id = DEFAULT_CHARACTER_ID
	register_character(hero)


func _register_tavern() -> void:
	if get_business("tavern") != null:
		return

	var tavern_type := DataRegistry.get_business_type("tavern")
	if tavern_type == null:
		push_warning("GameState: tavern business type not found")
		return

	var tavern := BusinessState.new()
	tavern.id = "tavern"
	tavern.type_id = "tavern"
	tavern.owner_id = TAVERN_OWNER_ID
	tavern.cash = TAVERN_STARTING_CASH
	tavern.storage = {"ale": 200, "wine": 100}

	for good_id in tavern_type.allowed_goods:
		var good_key := str(good_id)
		if BusinessEconomy.is_sellable_good(good_key):
			tavern.price_levels[good_key] = DemandFormula.DEFAULT_LEVEL

	tavern.sync_prices_from_levels()
	register_business(tavern)


func _seed_demo() -> void:
	var scenario := DataRegistry.get_scenario("default_scenario")
	if scenario == null:
		push_warning("GameState: default_scenario not found")
		return

	var business_type := DataRegistry.get_business_type(scenario.starting_business_type)
	if business_type == null:
		push_warning(
			"GameState: starting business type \"%s\" not found" % scenario.starting_business_type
		)
		return

	scenario_id = scenario.id
	simulation_seed = scenario.simulation_seed
	demand_formula_id = scenario.demand_formula_id
	reputation_formula_id = scenario.reputation_formula_id
	voting_formula_id = scenario.voting_formula_id
	proposed_law_id = scenario.proposed_law_id
	council_vote_interval_days = scenario.council_vote_interval_days
	council_first_vote_day = scenario.council_first_vote_day
	last_vote_day = 0
	last_vote_result = null
	laws.clear()
	characters.clear()

	player_reputation = ReputationState.new()
	player_reputation.owner_id = DEFAULT_PLAYER_ID
	player_reputation.value = scenario.starting_player_reputation

	var business := BusinessState.new()
	business.id = business_type.id
	business.type_id = business_type.id
	business.owner_id = DEFAULT_PLAYER_ID
	business.cash = scenario.starting_cash

	for good_id in scenario.starting_goods:
		business.storage[str(good_id)] = BusinessEconomy.DEFAULT_STARTING_GOOD_QUANTITY

	for good_id in business_type.allowed_goods:
		var good_key := str(good_id)
		if BusinessEconomy.is_sellable_good(good_key):
			business.price_levels[good_key] = DemandFormula.DEFAULT_LEVEL

	business.sync_prices_from_levels()
	register_business(business)

	_register_tavern()

	for npc in NpcSpawner.create_starting_npcs(scenario, simulation_seed):
		register_npc(npc)

	_ensure_npc_demand_profiles()
	_ensure_player_character()

	_seeded = true

	EventBus.reputation_changed.emit(
		player_reputation.owner_id,
		player_reputation.clamped_value(get_reputation_formula()),
		0.0,
	)
	EventBus.npcs_initialized.emit()
	EventBus.characters_initialized.emit()
