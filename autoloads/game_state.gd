extends Node
## Автозагрузка "GameState". Единственный источник правды о состоянии симуляции.
## Сцены в /world и /ui ЧИТАЮТ отсюда, но не хранят собственных копий данных.

var city: CityData = CityData.new()

var families: Dictionary = {}    # family_id (String) -> FamilyData
var characters: Dictionary = {}  # character_id (String) -> CharacterData
var buildings: Dictionary = {}   # building_id (String) -> BuildingData


func get_character(id: String) -> CharacterData:
	return characters.get(id, null)


func get_family(id: String) -> FamilyData:
	return families.get(id, null)


func get_building(id: String) -> BuildingData:
	return buildings.get(id, null)


func register_character(data: CharacterData) -> void:
	characters[data.id] = data


func register_family(data: FamilyData) -> void:
	families[data.id] = data


func register_building(data: BuildingData) -> void:
	buildings[data.id] = data


func get_workers(building: BuildingData) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for worker_id in building.worker_ids:
		var c := get_character(worker_id)
		if c != null:
			result.append(c)
	return result
