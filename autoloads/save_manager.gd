extends Node
## Сохранение и загрузка игрового состояния в JSON (user://saves/).


const SAVE_FORMAT_VERSION := 9
const SAVE_DIR := "user://saves/"

var _slot_name_pattern: RegEx


func _ready() -> void:
	_slot_name_pattern = RegEx.new()
	_slot_name_pattern.compile("^[a-zA-Z0-9_\\-]+$")


func save_game(slot_name: String) -> SaveResult:
	var slot_validation := _validate_slot_name(slot_name)
	if not slot_validation.success:
		return slot_validation

	var save_data := {
		"save_version": SAVE_FORMAT_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"scenario_id": GameState.scenario_id,
		"simulation_clock": SimulationClock.to_dict(),
		"game_state": GameState.to_dict(),
		"finance_history": FinanceHistory.to_dict(),
	}

	var path := _slot_path(slot_name)
	_ensure_save_dir()
	var json_text := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return SaveResult.fail("Cannot write save file: %s" % path)

	file.store_string(json_text)
	file.close()
	print("[SaveManager] saved slot \"%s\" (day %d)" % [slot_name, SimulationClock.day])
	return SaveResult.ok()


func load_game(slot_name: String) -> SaveResult:
	var slot_validation := _validate_slot_name(slot_name)
	if not slot_validation.success:
		return slot_validation

	var path := _slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return SaveResult.fail("Save slot not found: %s" % slot_name)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return SaveResult.fail("Cannot read save file: %s" % path)

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		return SaveResult.fail("Invalid save file format in slot \"%s\"" % slot_name)

	var data: Dictionary = parsed
	var version := int(data.get("save_version", 0))
	if version != SAVE_FORMAT_VERSION:
		return SaveResult.fail(
			"Unsupported save version %d (expected %d)" % [version, SAVE_FORMAT_VERSION]
		)

	SimulationClock.from_dict(data.get("simulation_clock", {}))

	var game_state_result := GameState.from_dict(data.get("game_state", {}))
	if not game_state_result.success:
		return game_state_result

	GameState.scenario_id = str(data.get("scenario_id", GameState.scenario_id))

	var finance_result := FinanceHistory.from_dict(data.get("finance_history", {}))
	if not finance_result.success:
		return finance_result

	PoliticsHistory.rebuild_from_save()
	_emit_post_load_events(slot_name)
	print("[SaveManager] loaded slot \"%s\" (day %d)" % [slot_name, SimulationClock.day])
	return SaveResult.ok()


func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	_ensure_save_dir()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var slot := file_name.trim_suffix(".json")
			var meta := _read_save_metadata(slot)
			if not meta.is_empty():
				saves.append(meta)
		file_name = dir.get_next()
	dir.list_dir_end()

	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0))
	)
	return saves


func _emit_post_load_events(slot_name: String) -> void:
	EventBus.game_loaded.emit(slot_name)
	EventBus.npcs_initialized.emit()
	EventBus.characters_initialized.emit()
	EventBus.state_changed.emit()
	EventBus.time_of_day_changed.emit(SimulationClock.get_time_of_day_normalized())
	EventBus.simulation_paused_changed.emit(SimulationClock.paused)
	EventBus.simulation_speed_changed.emit(SimulationClock.speed_multiplier)

	if GameState.player_reputation != null:
		var formula := GameState.get_reputation_formula()
		EventBus.reputation_changed.emit(
			GameState.player_reputation.owner_id,
			GameState.player_reputation.clamped_value(formula),
			0.0,
		)

	if GameState.get_business("bakery") != null:
		EventBus.business_selected.emit("bakery")


func _read_save_metadata(slot_name: String) -> Dictionary:
	var path := _slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return {}

	var data: Dictionary = parsed
	var clock: Dictionary = data.get("simulation_clock", {})
	return {
		"slot": slot_name,
		"save_version": int(data.get("save_version", 0)),
		"saved_at_unix": int(data.get("saved_at_unix", 0)),
		"scenario_id": str(data.get("scenario_id", "")),
		"day": int(clock.get("day", 0)),
	}


func _validate_slot_name(slot_name: String) -> SaveResult:
	var trimmed := slot_name.strip_edges()
	if trimmed.is_empty():
		return SaveResult.fail("Slot name cannot be empty")
	if trimmed.length() > 64:
		return SaveResult.fail("Slot name too long (max 64)")
	if _slot_name_pattern.search(trimmed) == null:
		return SaveResult.fail("Slot name may only contain letters, digits, _ and -")
	return SaveResult.ok()


func _slot_path(slot_name: String) -> String:
	return SAVE_DIR.path_join("%s.json" % slot_name.strip_edges())


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
