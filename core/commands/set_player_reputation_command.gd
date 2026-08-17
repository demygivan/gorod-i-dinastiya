class_name SetPlayerReputationCommand
extends RefCounted
## Установка репутации игрока (debug / будущие системы).


static func execute(owner_id: String, new_value: float) -> CommandResult:
	if GameState.player_reputation == null:
		return CommandResult.fail("Репутация игрока не инициализирована")
	if owner_id.is_empty():
		return CommandResult.fail("Не указан owner_id")
	if GameState.player_reputation.owner_id != owner_id:
		return CommandResult.fail("Неизвестный владелец: %s" % owner_id)

	var formula := GameState.get_reputation_formula()
	var previous := GameState.player_reputation.value
	if formula != null:
		GameState.player_reputation.value = clampf(
			new_value,
			formula.min_value,
			formula.max_value,
		)
	else:
		GameState.player_reputation.value = clampf(new_value, 0.0, 100.0)

	var applied := GameState.player_reputation.value - previous
	EventBus.reputation_changed.emit(owner_id, GameState.player_reputation.value, applied)
	EventBus.state_changed.emit()
	return CommandResult.ok()
