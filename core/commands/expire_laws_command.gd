class_name ExpireLawsCommand
extends RefCounted
## Деактивирует законы, срок действия которых истёк.


static func execute(current_day: int) -> CommandResult:
	for raw_law_id in GameState.laws:
		var law_state: LawState = GameState.laws[raw_law_id]
		if law_state == null or not law_state.is_active:
			continue
		if not law_state.is_expired(current_day):
			continue

		law_state.is_active = false
		EventBus.law_expired.emit(str(raw_law_id), current_day)

	EventBus.state_changed.emit()
	return CommandResult.ok()
