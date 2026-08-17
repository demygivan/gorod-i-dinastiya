@tool
class_name BuildingSpawnPool
extends Resource
## Пул зданий для случайной застройки слотов карты.


@export var id: String = "default"
@export var entries: Array[BuildingSpawnEntry] = []


func get_entry_by_id(entry_id: String) -> BuildingSpawnEntry:
	for entry in entries:
		if entry != null and entry.id == entry_id:
			return entry
	return null


func get_eligible_entries(slot_kind: String) -> Array[BuildingSpawnEntry]:
	var result: Array[BuildingSpawnEntry] = []
	for entry in entries:
		if entry != null and entry.matches_slot_kind(slot_kind) and entry.weight > 0.0:
			result.append(entry)
	return result


func pick_entry(slot_kind: String, rng: RandomNumberGenerator) -> BuildingSpawnEntry:
	var eligible := get_eligible_entries(slot_kind)
	if eligible.is_empty():
		return null

	var total_weight := 0.0
	for entry in eligible:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	var accumulated := 0.0
	for entry in eligible:
		accumulated += entry.weight
		if roll <= accumulated:
			return entry
	return eligible[eligible.size() - 1]
