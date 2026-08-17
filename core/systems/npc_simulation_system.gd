extends Node
## Логическое движение NPC по сетке. Только SimulationClock, без пикселей.


const MIN_IDLE_TICKS := 2
const MAX_IDLE_TICKS := 5
## Keep in sync with NpcView.walk_speed and CityPlaceholderTileset.TILE_SIZE.
const CELL_MOVE_SPEED := 90.0
const TILE_SIZE := 32
const SECONDS_PER_CELL := TILE_SIZE / CELL_MOVE_SPEED
const DEFAULT_LEAVE_HOUR := 6
const DEFAULT_SLEEP_HOUR := 0
const PARK_VISIT_HOURS := 4
const PARK_PICK_CHANCE := 0.05

var _navigation: CityNavigationSystem
var _step_accumulator: float = 0.0
var _spawned_cells := false
var _decision_nonce: int = 0


func _ready() -> void:
	SimulationClock.tick_elapsed.connect(_on_tick_elapsed)
	SimulationClock.hour_changed.connect(_on_hour_changed)
	EventBus.game_loaded.connect(_on_game_loaded)
	_resolve_navigation()


func _resolve_navigation() -> void:
	_navigation = get_tree().get_first_node_in_group("city_navigation") as CityNavigationSystem
	_ensure_starting_cells()


func _on_game_loaded(_slot_name: String) -> void:
	_spawned_cells = false
	_step_accumulator = 0.0
	_decision_nonce = 0
	_ensure_starting_cells()


func _on_hour_changed(hour: int) -> void:
	_ensure_starting_cells()
	var updates := _compute_schedule_updates(hour)
	if not updates.is_empty():
		CommandProcessor.execute(TickNpcMovementCommand.execute, [updates], false)


func _on_tick_elapsed(sim_delta: float) -> void:
	if _navigation == null:
		_resolve_navigation()
	if _navigation == null or not _navigation.is_ready_for_pathfinding():
		return
	_ensure_starting_cells()

	_step_accumulator += sim_delta
	if _step_accumulator < SECONDS_PER_CELL:
		return

	var updates: Array = []
	while _step_accumulator >= SECONDS_PER_CELL:
		_step_accumulator -= SECONDS_PER_CELL
		updates = _compute_step_updates()
		if not updates.is_empty():
			CommandProcessor.execute(TickNpcMovementCommand.execute, [updates], false)


func _ensure_starting_cells() -> void:
	if _spawned_cells:
		return
	if _navigation == null or not _navigation.is_ready_for_pathfinding():
		return

	var houses := _navigation.get_house_homes()
	var updates: Array = []
	var index := 0
	for npc in GameState.get_npcs_sorted():
		if not npc.home_slot_id.is_empty() and npc.has_cell():
			index += 1
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s:nav_spawn" % [GameState.simulation_seed, npc.id])
		var home_cell := NpcState.UNSET_CELL
		var home_slot_id := ""
		if not houses.is_empty():
			var house: Dictionary = houses[index % houses.size()]
			home_slot_id = str(house.get("slot_id", ""))
			home_cell = NpcState._cell_from_variant(house.get("door", NpcState.UNSET_CELL))
		if home_cell.x < 0:
			home_cell = _navigation.pick_road_cell(Vector2i.ZERO, 999, rng)
		updates.append({
			"id": npc.id,
			"current_cell": home_cell,
			"home_cell": home_cell,
			"home_slot_id": home_slot_id,
			"movement_state": NpcState.MovementState.AT_HOME,
			"path_cells": [],
			"idle_ticks_left": 0,
			"activity_until_abs_minute": 0,
		})
		index += 1

	_spawned_cells = true
	if not updates.is_empty():
		CommandProcessor.execute(TickNpcMovementCommand.execute, [updates], false)

	if _is_awake_hour(SimulationClock.hour):
		var leave_updates := _compute_schedule_updates(SimulationClock.hour)
		if not leave_updates.is_empty():
			CommandProcessor.execute(TickNpcMovementCommand.execute, [leave_updates], false)


func _compute_schedule_updates(hour: int) -> Array:
	var updates: Array = []
	var awake := _is_awake_hour(hour)
	for npc in GameState.get_npcs_sorted():
		if not npc.has_cell():
			continue
		if awake:
			if npc.movement_state == NpcState.MovementState.AT_HOME:
				var leave := _leave_home_update(npc)
				if not leave.is_empty():
					updates.append(leave)
		elif npc.movement_state != NpcState.MovementState.AT_HOME \
				and npc.movement_state != NpcState.MovementState.RETURNING_HOME:
			var going_home := _return_home_update(npc)
			if not going_home.is_empty():
				updates.append(going_home)
	return updates


func _compute_step_updates() -> Array:
	var updates: Array = []
	for npc in GameState.get_npcs_sorted():
		if not npc.has_cell():
			continue
		var update := _step_npc(npc)
		if not update.is_empty():
			updates.append(update)
	return updates


func _step_npc(npc: NpcState) -> Dictionary:
	var awake := _is_awake_hour(SimulationClock.hour)

	if not awake:
		if npc.movement_state == NpcState.MovementState.AT_HOME:
			return {}
		if npc.movement_state == NpcState.MovementState.RETURNING_HOME \
				and not npc.path_cells.is_empty():
			return _follow_path_update(npc, true)
		if npc.home_cell == npc.current_cell:
			return {
				"id": npc.id,
				"movement_state": NpcState.MovementState.AT_HOME,
				"path_cells": [],
				"idle_ticks_left": 0,
				"activity_until_abs_minute": 0,
			}
		return _return_home_update(npc)

	if npc.movement_state == NpcState.MovementState.AT_HOME:
		return _leave_home_update(npc)

	if npc.movement_state == NpcState.MovementState.STROLLING_PARK:
		return _step_park_stroll(npc)

	if npc.movement_state == NpcState.MovementState.MOVING_TO_GOAL and not npc.path_cells.is_empty():
		return _follow_path_update(npc, false)

	if npc.idle_ticks_left > 0:
		return {
			"id": npc.id,
			"idle_ticks_left": npc.idle_ticks_left - 1,
			"movement_state": NpcState.MovementState.IDLE_WANDER,
			"path_cells": [],
		}

	return _start_daytime_goal_update(npc)


func _follow_path_update(npc: NpcState, returning_home: bool) -> Dictionary:
	var next_cell: Vector2i = npc.path_cells[0]
	var remaining: Array[Vector2i] = []
	for index in range(1, npc.path_cells.size()):
		remaining.append(npc.path_cells[index])
	var arrived := remaining.is_empty()
	if returning_home:
		return {
			"id": npc.id,
			"current_cell": next_cell,
			"path_cells": remaining,
			"movement_state": (
				NpcState.MovementState.AT_HOME if arrived
				else NpcState.MovementState.RETURNING_HOME
			),
			"idle_ticks_left": 0,
			"activity_until_abs_minute": 0,
		}

	if npc.movement_state == NpcState.MovementState.STROLLING_PARK:
		var park_update := {
			"id": npc.id,
			"current_cell": next_cell,
			"path_cells": remaining,
			"movement_state": NpcState.MovementState.STROLLING_PARK,
		}
		if arrived:
			var park_rng := _npc_rng(npc, "park_arrive")
			park_update["idle_ticks_left"] = park_rng.randi_range(MIN_IDLE_TICKS, MAX_IDLE_TICKS)
		return park_update

	var update := {
		"id": npc.id,
		"current_cell": next_cell,
		"path_cells": remaining,
		"movement_state": (
			NpcState.MovementState.IDLE_WANDER if arrived
			else NpcState.MovementState.MOVING_TO_GOAL
		),
	}
	if arrived:
		var rng := _npc_rng(npc, "arrive")
		update["idle_ticks_left"] = rng.randi_range(MIN_IDLE_TICKS, MAX_IDLE_TICKS)
		if _navigation.is_park_cell(next_cell):
			update["movement_state"] = NpcState.MovementState.STROLLING_PARK
			update["activity_until_abs_minute"] = _absolute_minute() + PARK_VISIT_HOURS * 60
	return update


func _leave_home_update(npc: NpcState) -> Dictionary:
	var update := _start_daytime_goal_update(npc)
	if update.is_empty():
		return {
			"id": npc.id,
			"current_cell": npc.home_cell if npc.home_cell.x >= 0 else npc.current_cell,
			"movement_state": NpcState.MovementState.IDLE_WANDER,
			"path_cells": [],
			"idle_ticks_left": 0,
			"activity_until_abs_minute": 0,
		}
	update["current_cell"] = npc.home_cell if npc.home_cell.x >= 0 else npc.current_cell
	update["activity_until_abs_minute"] = 0
	return update


func _return_home_update(npc: NpcState) -> Dictionary:
	var home := npc.home_cell if npc.home_cell.x >= 0 else npc.current_cell
	if home == npc.current_cell:
		return {
			"id": npc.id,
			"movement_state": NpcState.MovementState.AT_HOME,
			"path_cells": [],
			"idle_ticks_left": 0,
			"activity_until_abs_minute": 0,
		}

	var path := _navigation.find_path(npc.current_cell, home)
	if path.is_empty():
		return {
			"id": npc.id,
			"current_cell": home,
			"movement_state": NpcState.MovementState.AT_HOME,
			"path_cells": [],
			"idle_ticks_left": 0,
			"activity_until_abs_minute": 0,
		}

	return {
		"id": npc.id,
		"movement_state": NpcState.MovementState.RETURNING_HOME,
		"path_cells": path,
		"idle_ticks_left": 0,
		"activity_until_abs_minute": 0,
	}


func _start_daytime_goal_update(npc: NpcState) -> Dictionary:
	var rng := _npc_rng(npc, "day_goal")
	var origin := npc.current_cell if npc.has_cell() else npc.home_cell
	var goal := NpcState.UNSET_CELL
	var going_to_park := false
	if _navigation.has_park() and rng.randf() < PARK_PICK_CHANCE:
		goal = _navigation.pick_park_end_cell(origin, rng)
		going_to_park = goal.x >= 0
	if not going_to_park:
		goal = _navigation.pick_production_door(rng, npc.current_cell)
	if goal.x < 0 or goal == npc.current_cell:
		return {
			"id": npc.id,
			"idle_ticks_left": rng.randi_range(MIN_IDLE_TICKS, MAX_IDLE_TICKS),
			"movement_state": NpcState.MovementState.IDLE_WANDER,
			"activity_until_abs_minute": 0,
		}

	var path := _navigation.find_path(origin, goal)
	if path.is_empty():
		return {
			"id": npc.id,
			"idle_ticks_left": rng.randi_range(MIN_IDLE_TICKS, MAX_IDLE_TICKS),
			"movement_state": NpcState.MovementState.IDLE_WANDER,
			"activity_until_abs_minute": 0,
		}

	return {
		"id": npc.id,
		"movement_state": NpcState.MovementState.MOVING_TO_GOAL,
		"path_cells": path,
		"idle_ticks_left": 0,
		"activity_until_abs_minute": 0,
	}


func _step_park_stroll(npc: NpcState) -> Dictionary:
	if _absolute_minute() >= npc.activity_until_abs_minute:
		return _start_daytime_goal_update(npc)

	if not npc.path_cells.is_empty():
		return _follow_path_update(npc, false)

	if npc.idle_ticks_left > 0:
		return {
			"id": npc.id,
			"idle_ticks_left": npc.idle_ticks_left - 1,
			"movement_state": NpcState.MovementState.STROLLING_PARK,
			"path_cells": [],
		}

	return _start_park_stroll_update(npc)


func _start_park_stroll_update(npc: NpcState) -> Dictionary:
	var rng := _npc_rng(npc, "park_stroll")
	var origin := npc.current_cell
	var goal := _navigation.pick_park_end_cell(origin, rng)
	if goal.x < 0 or goal == origin:
		return {
			"id": npc.id,
			"idle_ticks_left": rng.randi_range(MIN_IDLE_TICKS, MAX_IDLE_TICKS),
			"movement_state": NpcState.MovementState.STROLLING_PARK,
			"path_cells": [],
		}

	var path := _navigation.find_path(origin, goal)
	if path.is_empty():
		return {
			"id": npc.id,
			"idle_ticks_left": rng.randi_range(MIN_IDLE_TICKS, MAX_IDLE_TICKS),
			"movement_state": NpcState.MovementState.STROLLING_PARK,
			"path_cells": [],
		}

	return {
		"id": npc.id,
		"movement_state": NpcState.MovementState.STROLLING_PARK,
		"path_cells": path,
		"idle_ticks_left": 0,
	}


func _is_awake_hour(hour: int) -> bool:
	var leave_hour := DEFAULT_LEAVE_HOUR
	var sleep_hour := DEFAULT_SLEEP_HOUR
	var scenario := GameState.get_scenario()
	if scenario != null:
		leave_hour = scenario.npc_leave_home_hour
		sleep_hour = scenario.npc_sleep_hour
	if leave_hour == sleep_hour:
		return true
	if leave_hour < sleep_hour:
		return hour >= leave_hour and hour < sleep_hour
	return hour >= leave_hour or hour < sleep_hour


func _absolute_minute() -> int:
	return (
		(SimulationClock.day - 1) * SimulationClock.HOURS_PER_DAY
		* SimulationClock.MINUTES_PER_HOUR
		+ SimulationClock.hour * SimulationClock.MINUTES_PER_HOUR
		+ SimulationClock.minute
	)


func _npc_rng(npc: NpcState, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	_decision_nonce += 1
	rng.seed = hash("%d:%s:%s:%d" % [
		GameState.simulation_seed,
		npc.id,
		salt,
		_decision_nonce,
	])
	return rng
