class_name HireWorkerCommand
extends RefCounted
## Единственный легальный способ назначить персонажа работником здания.
## UI НИКОГДА не пишет напрямую в character.job_building_id / building.worker_ids —
## только вызывает execute() и реагирует на результат/событие.

static func execute(character_id: String, building_id: String) -> CommandResult:
	var character := GameState.get_character(character_id)
	var building := GameState.get_building(building_id)

	var validation := _validate(character, building)
	if not validation.success:
		return validation

	character.job_building_id = building.id
	building.worker_ids.append(character.id)

	EventBus.character_hired.emit(character.id, building.id)
	return CommandResult.ok()


static func _validate(character: CharacterData, building: BuildingData) -> CommandResult:
	if character == null:
		return CommandResult.fail("Персонаж не найден")
	if building == null:
		return CommandResult.fail("Здание не найдено")
	if not character.is_alive:
		return CommandResult.fail("Персонаж мёртв")
	if character.is_in_jail:
		return CommandResult.fail("Персонаж в тюрьме")
	if character.job_building_id != "":
		return CommandResult.fail("Персонаж уже работает")
	return CommandResult.ok()
