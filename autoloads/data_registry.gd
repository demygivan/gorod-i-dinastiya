extends Node
## Реестр статических определений из data/. Только загрузка данных, без игровой логики.

const GOODS_DIR := "res://data/goods"
const BUSINESS_TYPES_DIR := "res://data/businesses"
const SCENARIOS_DIR := "res://data/scenarios"
const DEMAND_DIR := "res://data/demand"
const NPC_ARCHETYPES_DIR := "res://data/npc_archetypes"
const REPUTATION_DIR := "res://data/reputation"
const LAWS_DIR := "res://data/laws"
const POLITICS_DIR := "res://data/politics"

var _goods: Dictionary = {}          ## good_id (String) -> GoodDefinition
var _business_types: Dictionary = {} ## business_type_id (String) -> BusinessTypeDefinition
var _scenarios: Dictionary = {}      ## scenario_id (String) -> ScenarioDefinition
var _demand_formulas: Dictionary = {} ## formula_id (String) -> DemandFormula
var _npc_archetypes: Dictionary = {} ## archetype_id (String) -> NpcArchetypeDefinition
var _reputation_formulas: Dictionary = {} ## formula_id (String) -> ReputationFormula
var _laws: Dictionary = {} ## law_id (String) -> LawDefinition
var _voting_formulas: Dictionary = {} ## formula_id (String) -> VotingFormula


func _ready() -> void:
	reload()


func reload() -> void:
	_goods.clear()
	_business_types.clear()
	_scenarios.clear()
	_demand_formulas.clear()
	_npc_archetypes.clear()
	_reputation_formulas.clear()
	_laws.clear()
	_voting_formulas.clear()

	_load_goods()
	_load_business_types()
	_load_scenarios()
	_load_demand_formulas()
	_load_npc_archetypes()
	_load_reputation_formulas()
	_load_laws()
	_load_voting_formulas()
	_validate_references()

	print(
		"[DataRegistry] goods=%d business_types=%d scenarios=%d demand_formulas=%d npc_archetypes=%d reputation_formulas=%d laws=%d voting_formulas=%d" % [
			_goods.size(),
			_business_types.size(),
			_scenarios.size(),
			_demand_formulas.size(),
			_npc_archetypes.size(),
			_reputation_formulas.size(),
			_laws.size(),
			_voting_formulas.size(),
		]
	)


func get_good(id: String) -> GoodDefinition:
	return _goods.get(id, null)


func get_business_type(id: String) -> BusinessTypeDefinition:
	return _business_types.get(id, null)


func get_scenario(id: String) -> ScenarioDefinition:
	return _scenarios.get(id, null)


func get_demand_formula(id: String) -> DemandFormula:
	return _demand_formulas.get(id, null)


func get_npc_archetype(id: String) -> NpcArchetypeDefinition:
	return _npc_archetypes.get(id, null)


func get_npc_archetype_name(id: String) -> String:
	var archetype := get_npc_archetype(id)
	return tr(archetype.name_key) if archetype != null else id


func get_reputation_formula(id: String) -> ReputationFormula:
	return _reputation_formulas.get(id, null)


func get_law(id: String) -> LawDefinition:
	return _laws.get(id, null)


func get_law_name(id: String) -> String:
	var law := get_law(id)
	return tr(law.name_key) if law != null else id


func get_voting_formula(id: String) -> VotingFormula:
	return _voting_formulas.get(id, null)


func get_laws() -> Array[LawDefinition]:
	var result: Array[LawDefinition] = []
	for law_id in _laws:
		result.append(_laws[law_id])
	result.sort_custom(func(a: LawDefinition, b: LawDefinition) -> bool: return a.id < b.id)
	return result


func get_goods() -> Array[GoodDefinition]:
	var result: Array[GoodDefinition] = []
	for good_id in _goods:
		result.append(_goods[good_id])
	result.sort_custom(_sort_goods)
	return result


func get_business_types() -> Array[BusinessTypeDefinition]:
	var result: Array[BusinessTypeDefinition] = []
	for type_id in _business_types:
		result.append(_business_types[type_id])
	return result


func get_scenarios() -> Array[ScenarioDefinition]:
	var result: Array[ScenarioDefinition] = []
	for scenario_id in _scenarios:
		result.append(_scenarios[scenario_id])
	return result


func get_good_name(id: String) -> String:
	var good := get_good(id)
	return tr(good.name_key) if good != null else id


func get_good_price(id: String) -> float:
	var good := get_good(id)
	return good.base_price if good != null else 0.0


func get_business_type_name(id: String) -> String:
	var business_type := get_business_type(id)
	return tr(business_type.name_key) if business_type != null else id


func get_category_name(category: String) -> String:
	if category.is_empty():
		return ""
	return tr("label.category.%s" % category)


func get_recipe_inputs(good_id: String) -> Array[String]:
	var good := get_good(good_id)
	if good == null:
		return []
	return good.input_ids.duplicate()


func get_goods_made_from(good_id: String) -> Array[GoodDefinition]:
	var result: Array[GoodDefinition] = []
	if good_id.is_empty():
		return result
	for good in get_goods():
		if good.input_ids.has(good_id):
			result.append(good)
	return result


func format_recipe_suffix(good: GoodDefinition) -> String:
	var parts: PackedStringArray = []
	if not good.input_ids.is_empty():
		var input_names: PackedStringArray = []
		for input_id in good.input_ids:
			input_names.append(get_good_name(str(input_id)))
		parts.append(LocaleService.trf("label.recipe.inputs", {"names": ", ".join(input_names)}))

	var outputs := get_goods_made_from(good.id)
	if not outputs.is_empty():
		var output_names: PackedStringArray = []
		for output_good in outputs:
			output_names.append(get_good_name(output_good.id))
		parts.append(LocaleService.trf("label.recipe.outputs", {"names": ", ".join(output_names)}))

	if parts.is_empty():
		return ""
	return "  %s" % "  ".join(parts)


func _load_goods() -> void:
	for path in _list_definition_paths(GOODS_DIR):
		var good := load(path) as GoodDefinition
		if good == null:
			push_error("[DataRegistry] %s is not a GoodDefinition" % path)
			continue
		_store(_goods, good.id, good, path)


func _load_business_types() -> void:
	for path in _list_definition_paths(BUSINESS_TYPES_DIR):
		var business_type := load(path) as BusinessTypeDefinition
		if business_type == null:
			push_error("[DataRegistry] %s is not a BusinessTypeDefinition" % path)
			continue
		_store(_business_types, business_type.id, business_type, path)


func _load_scenarios() -> void:
	for path in _list_definition_paths(SCENARIOS_DIR):
		var scenario := load(path) as ScenarioDefinition
		if scenario == null:
			push_error("[DataRegistry] %s is not a ScenarioDefinition" % path)
			continue
		_store(_scenarios, scenario.id, scenario, path)


func _load_demand_formulas() -> void:
	for path in _list_definition_paths(DEMAND_DIR):
		var formula := load(path) as DemandFormula
		if formula == null:
			push_error("[DataRegistry] %s is not a DemandFormula" % path)
			continue
		_store(_demand_formulas, formula.id, formula, path)


func _load_npc_archetypes() -> void:
	for path in _list_definition_paths(NPC_ARCHETYPES_DIR):
		var archetype := load(path) as NpcArchetypeDefinition
		if archetype == null:
			push_error("[DataRegistry] %s is not a NpcArchetypeDefinition" % path)
			continue
		_store(_npc_archetypes, archetype.archetype_id, archetype, path)


func _load_reputation_formulas() -> void:
	for path in _list_definition_paths(REPUTATION_DIR):
		var formula := load(path) as ReputationFormula
		if formula == null:
			push_error("[DataRegistry] %s is not a ReputationFormula" % path)
			continue
		_store(_reputation_formulas, formula.id, formula, path)


func _load_laws() -> void:
	for path in _list_definition_paths(LAWS_DIR):
		var law := load(path) as LawDefinition
		if law == null:
			push_error("[DataRegistry] %s is not a LawDefinition" % path)
			continue
		_store(_laws, law.id, law, path)


func _load_voting_formulas() -> void:
	for path in _list_definition_paths(POLITICS_DIR):
		var formula := load(path) as VotingFormula
		if formula == null:
			push_error("[DataRegistry] %s is not a VotingFormula" % path)
			continue
		_store(_voting_formulas, formula.id, formula, path)


func _store(target: Dictionary, id: String, definition: Resource, path: String) -> void:
	if id.is_empty():
		push_error("[DataRegistry] %s has an empty id" % path)
		return
	if target.has(id):
		push_error("[DataRegistry] duplicate id \"%s\" in %s" % [id, path])
		return
	target[id] = definition


func _validate_references() -> void:
	for good in get_goods():
		if good.is_primary():
			continue
		if good.input_ids.is_empty():
			push_warning(
				"[DataRegistry] processed good \"%s\" has no recipe inputs" % good.id
			)
		for input_id in good.input_ids:
			if not _goods.has(input_id):
				push_warning(
					"[DataRegistry] good \"%s\" requires unknown input \"%s\"" % [
						good.id,
						input_id,
					]
				)

	for business_type in get_business_types():
		for good_id in business_type.allowed_goods:
			if not _goods.has(good_id):
				push_warning(
					"[DataRegistry] business type \"%s\" allows unknown good \"%s\"" % [
						business_type.id,
						good_id,
					]
				)

	for scenario in get_scenarios():
		if not _business_types.has(scenario.starting_business_type):
			push_warning(
				"[DataRegistry] scenario \"%s\" starts with unknown business type \"%s\"" % [
					scenario.id,
					scenario.starting_business_type,
				]
			)
		for good_id in scenario.starting_goods:
			if not _goods.has(good_id):
				push_warning(
					"[DataRegistry] scenario \"%s\" starts with unknown good \"%s\"" % [
						scenario.id,
						good_id,
					]
				)
		if not scenario.demand_formula_id.is_empty() and not _demand_formulas.has(scenario.demand_formula_id):
			push_warning(
				"[DataRegistry] scenario \"%s\" references unknown demand formula \"%s\"" % [
					scenario.id,
					scenario.demand_formula_id,
				]
			)
		if not scenario.reputation_formula_id.is_empty() and not _reputation_formulas.has(scenario.reputation_formula_id):
			push_warning(
				"[DataRegistry] scenario \"%s\" references unknown reputation formula \"%s\"" % [
					scenario.id,
					scenario.reputation_formula_id,
				]
			)
		if not scenario.voting_formula_id.is_empty() and not _voting_formulas.has(scenario.voting_formula_id):
			push_warning(
				"[DataRegistry] scenario \"%s\" references unknown voting formula \"%s\"" % [
					scenario.id,
					scenario.voting_formula_id,
				]
			)
		if not scenario.proposed_law_id.is_empty() and not _laws.has(scenario.proposed_law_id):
			push_warning(
				"[DataRegistry] scenario \"%s\" references unknown law \"%s\"" % [
					scenario.id,
					scenario.proposed_law_id,
				]
			)
		for archetype_id in scenario.starting_npc_archetypes:
			if not _npc_archetypes.has(archetype_id):
				push_warning(
					"[DataRegistry] scenario \"%s\" starts with unknown npc archetype \"%s\"" % [
						scenario.id,
						archetype_id,
					]
				)
		for archetype_id in scenario.npc_archetype_pool:
			if not _npc_archetypes.has(archetype_id):
				push_warning(
					"[DataRegistry] scenario \"%s\" pool has unknown npc archetype \"%s\"" % [
						scenario.id,
						archetype_id,
					]
				)

	for archetype_id in _npc_archetypes:
		var archetype: NpcArchetypeDefinition = _npc_archetypes[archetype_id]
		for good_id in archetype.preferred_goods:
			if not _goods.has(good_id):
				push_warning(
					"[DataRegistry] npc archetype \"%s\" prefers unknown good \"%s\"" % [
						archetype.archetype_id,
						good_id,
					]
				)


func _list_definition_paths(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()

	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("[DataRegistry] cannot open %s" % directory)
		return paths

	for file_name in dir.get_files():
		# В экспортированной сборке ресурсы лежат как *.tres.remap.
		var resource_name := file_name.trim_suffix(".remap")
		if resource_name.ends_with(".tres") or resource_name.ends_with(".res"):
			paths.append(directory.path_join(resource_name))

	paths.sort()
	return paths


func _sort_goods(a: GoodDefinition, b: GoodDefinition) -> bool:
	if a.category != b.category:
		return a.category < b.category
	return get_good_name(a.id) < get_good_name(b.id)
