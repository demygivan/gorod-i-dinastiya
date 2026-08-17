class_name MoveCharacterCommand
extends RefCounted
## Назначает путь играбельному персонажу к клетке сетки (AStar).


var character_id: String = ""
var target_cell: Vector2i = Vector2i(-1, -1)


func execute() -> CommandResult:
	var validation := _validate()
	if not validation.success:
		return validation

	var character := GameState.get_character(character_id)
	var navigation := _find_navigation()
	var resolved_target := target_cell
	if not navigation.is_walkable(resolved_target):
		resolved_target = navigation.get_door_node(resolved_target)
	if not navigation.is_walkable(resolved_target):
		return CommandResult.fail("Клетка непроходима")

	if resolved_target == character.current_cell:
		character.path_cells.clear()
		EventBus.character_arrived.emit(character.id, character.current_cell)
		EventBus.character_positions_changed.emit()
		return CommandResult.ok()

	var path := navigation.find_path(character.current_cell, resolved_target)
	if path.is_empty():
		return CommandResult.fail("Путь не найден")

	character.path_cells = path
	EventBus.character_path_changed.emit(character.id, resolved_target)
	EventBus.character_positions_changed.emit()
	return CommandResult.ok()


func _validate() -> CommandResult:
	if character_id.is_empty():
		return CommandResult.fail("Не указан character_id")
	var character := GameState.get_character(character_id)
	if character == null:
		return CommandResult.fail("Персонаж не найден")
	if not character.has_cell():
		return CommandResult.fail("Персонаж ещё не на карте")

	var navigation := _find_navigation()
	if navigation == null or not navigation.is_ready_for_pathfinding():
		return CommandResult.fail("Навигация не готова")
	if not navigation.is_in_bounds(target_cell):
		return CommandResult.fail("Клетка вне карты")
	return CommandResult.ok()


func _find_navigation() -> CityNavigationSystem:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("city_navigation") as CityNavigationSystem
