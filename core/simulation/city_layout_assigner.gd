class_name CityLayoutAssigner
extends RefCounted
## Распределение зданий по слотам карты. Сначала минимумы из пула, затем weighted random.


class Assignment:
	var slot_id: String = ""
	var entry_id: String = ""
	var name_key: String = ""
	var visual_kind: String = ""
	var business_type_id: String = ""
	var group: String = ""
	var is_fixed: bool = false


const TOWN_HALL_NAME_KEY := "building.town_hall"
const TOWN_HALL_VISUAL := "town_hall"
const CEMETERY_ID := "cemetery"
const CEMETERY_NAME_KEY := "building.cemetery"


static func assign(
	slots: Array,
	pool: BuildingSpawnPool,
	seed: int,
	player_business_type_id: String = "",
) -> Dictionary:
	var result: Dictionary = {}
	if pool == null:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var player_business_assigned := player_business_type_id.is_empty()
	var placed_counts: Dictionary = {}
	var remaining: Array = []

	var sorted_slots: Array = slots.duplicate()
	sorted_slots.sort_custom(func(a, b) -> bool:
		if a.grid_y != b.grid_y:
			return a.grid_y < b.grid_y
		return a.grid_x < b.grid_x
	)

	for slot in sorted_slots:
		if slot == null or slot.slot_id.is_empty():
			continue

		if slot.slot_kind == "gate":
			continue

		if slot.is_fixed or slot.slot_kind == "town_hall" or slot.slot_kind == "cemetery":
			var fixed := _assign_fixed_slot(slot, pool)
			if fixed != null:
				result[slot.slot_id] = fixed
				_count(placed_counts, fixed.entry_id)
			continue

		if not player_business_assigned and slot.slot_kind == "commercial":
			player_business_assigned = true
			var player_assignment := _assignment_from_player(slot, player_business_type_id)
			result[slot.slot_id] = player_assignment
			_count(placed_counts, player_assignment.entry_id)
			continue

		remaining.append(slot)

	_place_minimums(remaining, result, placed_counts, pool, rng)
	_fill_remaining(remaining, result, pool, rng)
	return result


static func _assign_fixed_slot(slot, pool: BuildingSpawnPool) -> Assignment:
	if slot.slot_kind == "cemetery" or slot.forced_type == CEMETERY_ID:
		var cemetery := pool.get_entry_by_id(CEMETERY_ID)
		if cemetery != null:
			return _assignment_from_entry(slot, cemetery, true)
		var fallback := Assignment.new()
		fallback.slot_id = slot.slot_id
		fallback.entry_id = CEMETERY_ID
		fallback.name_key = CEMETERY_NAME_KEY
		fallback.visual_kind = CEMETERY_ID
		fallback.group = "Scholar"
		fallback.is_fixed = true
		return fallback

	var hall := Assignment.new()
	hall.slot_id = slot.slot_id
	hall.entry_id = "town_hall"
	hall.name_key = TOWN_HALL_NAME_KEY
	hall.visual_kind = TOWN_HALL_VISUAL
	hall.group = "Infrastructure"
	hall.is_fixed = true
	return hall


static func _assignment_from_player(slot, player_business_type_id: String) -> Assignment:
	var assignment := Assignment.new()
	assignment.slot_id = slot.slot_id
	assignment.entry_id = player_business_type_id
	assignment.name_key = "business.%s" % player_business_type_id
	assignment.visual_kind = player_business_type_id
	assignment.business_type_id = player_business_type_id
	assignment.group = "Patron"
	return assignment


static func _assignment_from_entry(slot, entry: BuildingSpawnEntry, is_fixed: bool = false) -> Assignment:
	var assignment := Assignment.new()
	assignment.slot_id = slot.slot_id
	assignment.entry_id = entry.id
	assignment.name_key = entry.name_key
	assignment.visual_kind = entry.id
	assignment.business_type_id = entry.business_type_id
	assignment.group = entry.group
	assignment.is_fixed = is_fixed
	return assignment


static func _place_minimums(
	remaining: Array,
	result: Dictionary,
	placed_counts: Dictionary,
	pool: BuildingSpawnPool,
	rng: RandomNumberGenerator,
) -> void:
	for entry in pool.entries:
		if entry == null or entry.minimum_quantity <= 0:
			continue
		var still_needed := entry.minimum_quantity - int(placed_counts.get(entry.id, 0))
		for _i in range(still_needed):
			var slot_index := _find_matching_slot_index(remaining, entry, rng)
			if slot_index < 0:
				break
			var slot = remaining[slot_index]
			remaining.remove_at(slot_index)
			result[slot.slot_id] = _assignment_from_entry(slot, entry)
			_count(placed_counts, entry.id)


static func _fill_remaining(
	remaining: Array,
	result: Dictionary,
	pool: BuildingSpawnPool,
	rng: RandomNumberGenerator,
) -> void:
	for slot in remaining:
		var entry := pool.pick_entry(slot.slot_kind, rng)
		if entry == null:
			continue
		result[slot.slot_id] = _assignment_from_entry(slot, entry)


static func _find_matching_slot_index(
	remaining: Array,
	entry: BuildingSpawnEntry,
	rng: RandomNumberGenerator,
) -> int:
	var matches: Array[int] = []
	for i in remaining.size():
		var slot = remaining[i]
		if slot != null and entry.matches_slot_kind(slot.slot_kind):
			matches.append(i)
	if matches.is_empty():
		return -1
	return matches[rng.randi() % matches.size()]


static func _count(placed_counts: Dictionary, entry_id: String) -> void:
	if entry_id.is_empty():
		return
	placed_counts[entry_id] = int(placed_counts.get(entry_id, 0)) + 1
