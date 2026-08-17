class_name TickNpcMovementCommand
extends RefCounted
## Применяет очередной шаг навигации NPC (клетка, путь, состояние).


static func execute(updates: Array) -> CommandResult:
	if updates.is_empty():
		return CommandResult.ok()

	for raw_update in updates:
		if not raw_update is Dictionary:
			continue
		var update: Dictionary = raw_update
		var npc := GameState.get_npc(str(update.get("id", "")))
		if npc == null:
			continue
		if update.has("current_cell"):
			npc.current_cell = NpcState._cell_from_variant(update.get("current_cell"))
		if update.has("home_cell"):
			npc.home_cell = NpcState._cell_from_variant(update.get("home_cell"))
		if update.has("home_slot_id"):
			npc.home_slot_id = str(update.get("home_slot_id"))
		if update.has("movement_state"):
			npc.movement_state = int(update.get("movement_state"))
		if update.has("path_cells"):
			npc.path_cells = NpcState._path_from_variant(update.get("path_cells"))
		if update.has("idle_ticks_left"):
			npc.idle_ticks_left = int(update.get("idle_ticks_left"))
		if update.has("activity_until_abs_minute"):
			npc.activity_until_abs_minute = int(update.get("activity_until_abs_minute"))

	EventBus.npc_positions_changed.emit()
	return CommandResult.ok()
