extends Node2D
## Пример связки систем на сцене. Замени тестовые данные на загрузку
## реального сейва/стартового сценария, когда дойдёшь до этого этапа.

func _ready() -> void:
	_spawn_test_data()

	GameClock.day_passed.connect(_on_day_passed)
	GameClock.season_passed.connect(_on_season_passed)


func _spawn_test_data() -> void:
	var family := FamilyData.new()
	family.id = "family_1"
	family.family_name = "Смирновы"
	GameState.register_family(family)

	var farmer := CharacterData.new()
	farmer.id = "char_1"
	farmer.character_name = "Иван"
	farmer.family_id = family.id
	farmer.profession = Enums.Profession.CRAFTSMAN
	farmer.skills.craftsmanship = 8
	GameState.register_character(farmer)

	var farm := BuildingData.new()
	farm.id = "building_1"
	farm.building_type = Enums.BuildingType.FARM
	farm.function_type = Enums.BuildingFunction.PRODUCTION
	farm.owner_family_id = family.id
	farm.output_resource = "grain"
	GameState.register_building(farm)

	# Найм — ТОЛЬКО через команду, никогда прямым присвоением worker_ids.
	var result := HireWorkerCommand.execute(farmer.id, farm.id)
	if not result.success:
		push_warning("Не удалось нанять: %s" % result.error)

	GameState.city.population = 100


func _on_day_passed(_day: int) -> void:
	for building in GameState.buildings.values():
		ProductionSystem.process_day(building)
	for character in GameState.characters.values():
		CrimeSystem.tick_jail(character)


func _on_season_passed(_season: int) -> void:
	CityStatsSystem.recalculate_crime_rate(GameState.city)
