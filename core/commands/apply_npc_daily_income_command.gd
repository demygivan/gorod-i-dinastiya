class_name ApplyNpcDailyIncomeCommand
extends RefCounted
## Сброс дневного бюджета NPC до npc_income_per_day из сценария.


static func execute() -> CommandResult:
	var scenario := GameState.get_scenario()
	if scenario == null:
		return CommandResult.fail("Сценарий не найден")

	var income := scenario.npc_income_per_day
	if income <= 0.0:
		return CommandResult.ok()

	for npc in GameState.get_npcs_sorted():
		npc.cash = income
		EventBus.npc_cash_changed.emit(npc.id, npc.cash)

	EventBus.state_changed.emit()
	return CommandResult.ok()
