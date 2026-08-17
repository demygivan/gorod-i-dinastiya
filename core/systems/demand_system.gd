extends Node
## Дневной спрос жителей, вечерняя таверна и дневной цикл расходов. Только SimulationClock.


const TAVERN_TYPE_ID := "tavern"

var _processed_shopping_slots: Dictionary = {}  ## "day:hour" -> true
var _last_tavern_day: int = -1


func _ready() -> void:
	SimulationClock.hour_changed.connect(_on_hour_changed)
	SimulationClock.day_changed.connect(_on_day_changed)
	EventBus.game_loaded.connect(_on_game_loaded)


func reset_after_load() -> void:
	_processed_shopping_slots.clear()
	_last_tavern_day = -1


func _on_game_loaded(_slot_name: String) -> void:
	reset_after_load()


func _on_hour_changed(hour: int) -> void:
	_run_hourly_shopping(hour)
	_run_evening_tavern(hour)


func _run_hourly_shopping(hour: int) -> void:
	var scenario := GameState.get_scenario()
	if scenario == null:
		return
	if hour < scenario.shopping_hour_start or hour > scenario.shopping_hour_end:
		return

	var slot_key := "%d:%d" % [SimulationClock.day, hour]
	if _processed_shopping_slots.has(slot_key):
		return
	_processed_shopping_slots[slot_key] = true

	for business_id in GameState.businesses:
		var business := GameState.get_business(str(business_id))
		if business == null or business.type_id == TAVERN_TYPE_ID:
			continue
		CommandProcessor.execute(
			SimulateDailyDemandCommand.execute,
			[str(business_id), SimulationClock.day, hour],
		)


func _run_evening_tavern(hour: int) -> void:
	var scenario := GameState.get_scenario()
	if scenario == null:
		return
	if hour != scenario.tavern_hour:
		return
	if SimulationClock.day == _last_tavern_day:
		return

	var tavern := _find_tavern()
	if tavern == null:
		return

	_last_tavern_day = SimulationClock.day
	CommandProcessor.execute(
		SimulateTavernSpendingCommand.execute,
		[tavern.id, SimulationClock.day],
	)


func _on_day_changed(_new_day: int) -> void:
	CommandProcessor.execute(ApplyNpcDailyIncomeCommand.execute, [])

	var completed_day := SimulationClock.day - 1

	for business_id in GameState.businesses:
		var id := str(business_id)
		CommandProcessor.execute(ApplyDailyCostsCommand.execute, [id])
		CommandProcessor.execute(
			RecordDailyFinanceCommand.execute,
			[id, completed_day],
		)
		CommandProcessor.execute(ResetDailyStatsCommand.execute, [id])

	_processed_shopping_slots.clear()
	_last_tavern_day = -1


func _find_tavern() -> BusinessState:
	for business_id in GameState.businesses:
		var business := GameState.get_business(str(business_id))
		if business != null and business.type_id == TAVERN_TYPE_ID:
			return business
	return null
