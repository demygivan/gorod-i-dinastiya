class_name ProductionSystem
extends RefCounted
## Статические функции без состояния. Вызывать из подписки на
## GameClock.day_passed для каждого производственного здания.

static func process_day(building: BuildingData) -> void:
	if building.function_type != Enums.BuildingFunction.PRODUCTION:
		return

	var craft_bonus := 0
	for worker in GameState.get_workers(building):
		craft_bonus += worker.skills.craftsmanship

	var output: int = max(0, building.base_production + craft_bonus)
	building.stock += output

	EventBus.building_produced.emit(building.id, building.output_resource, output)
