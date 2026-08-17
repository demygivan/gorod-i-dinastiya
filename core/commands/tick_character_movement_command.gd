class_name TickCharacterMovementCommand
extends RefCounted
## Применяет очередной шаг навигации играбельного персонажа.


static func execute(updates: Array) -> CommandResult:
	if updates.is_empty():
		return CommandResult.ok()

	for raw_update in updates:
		if not raw_update is Dictionary:
			continue
		var update: Dictionary = raw_update
		var character := GameState.get_character(str(update.get("id", "")))
		if character == null:
			continue
		if update.has("current_cell"):
			character.current_cell = CharacterState._cell_from_variant(update.get("current_cell"))
		if update.has("path_cells"):
			character.path_cells = CharacterState._path_from_variant(update.get("path_cells"))
		if bool(update.get("arrived", false)):
			EventBus.character_arrived.emit(character.id, character.current_cell)

	EventBus.character_positions_changed.emit()
	return CommandResult.ok()
