extends Node
## Логическое движение играбельных персонажей по сетке. Только SimulationClock.


## Keep in sync with PlayerView.walk_speed and CityPlaceholderTileset.TILE_SIZE.
const CELL_MOVE_SPEED := 90.0
const TILE_SIZE := 32
const SECONDS_PER_CELL := TILE_SIZE / CELL_MOVE_SPEED

var _navigation: CityNavigationSystem
var _step_accumulator: float = 0.0
var _spawned := false


func _ready() -> void:
	SimulationClock.tick_elapsed.connect(_on_tick_elapsed)
	EventBus.game_loaded.connect(_on_game_loaded)
	_resolve_navigation()


func _resolve_navigation() -> void:
	_navigation = get_tree().get_first_node_in_group("city_navigation") as CityNavigationSystem
	_ensure_spawn()


func _on_game_loaded(_slot_name: String) -> void:
	_spawned = false
	_step_accumulator = 0.0
	_resolve_navigation()


func _on_tick_elapsed(sim_delta: float) -> void:
	if _navigation == null:
		_resolve_navigation()
	if _navigation == null or not _navigation.is_ready_for_pathfinding():
		return
	_ensure_spawn()

	_step_accumulator += sim_delta
	if _step_accumulator < SECONDS_PER_CELL:
		return

	var updates: Array = []
	while _step_accumulator >= SECONDS_PER_CELL:
		_step_accumulator -= SECONDS_PER_CELL
		updates = _compute_step_updates()
		if not updates.is_empty():
			CommandProcessor.execute(TickCharacterMovementCommand.execute, [updates], false)


func _ensure_spawn() -> void:
	if _spawned:
		return
	if _navigation == null or not _navigation.is_ready_for_pathfinding():
		return

	var updates: Array = []
	for character in GameState.get_characters_sorted():
		if character.has_cell():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s:town_hall_spawn" % [GameState.simulation_seed, character.id])
		updates.append({
			"id": character.id,
			"current_cell": _navigation.pick_town_hall_spawn_cell(rng),
			"path_cells": [],
		})

	_spawned = true
	if not updates.is_empty():
		CommandProcessor.execute(TickCharacterMovementCommand.execute, [updates], false)


func _compute_step_updates() -> Array:
	var updates: Array = []
	for character in GameState.get_characters_sorted():
		if not character.has_cell() or character.path_cells.is_empty():
			continue
		var next_cell: Vector2i = character.path_cells[0]
		var remaining: Array[Vector2i] = []
		for index in range(1, character.path_cells.size()):
			remaining.append(character.path_cells[index])
		updates.append({
			"id": character.id,
			"current_cell": next_cell,
			"path_cells": remaining,
			"arrived": remaining.is_empty(),
		})
	return updates
