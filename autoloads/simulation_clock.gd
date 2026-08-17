extends Node
## Игровое время: пауза, скорости x1/x2/x4, сутки (минуты/часы/дни).
## 1 игровая минута = 1 реальная секунда при скорости x1.

signal tick_elapsed(sim_delta: float)
signal minute_changed(minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)

const SPEED_OPTIONS: Array[int] = [1, 2, 4]
const MINUTES_PER_HOUR := 60
const HOURS_PER_DAY := 24
const SECONDS_PER_MINUTE := 1.0

var paused: bool = false
var speed_multiplier: int = 1

var minute: int = 0
var hour: int = 8
var day: int = 1

var _minute_accumulator: float = 0.0


func _ready() -> void:
	EventBus.time_of_day_changed.emit(get_time_of_day_normalized())


func _process(delta: float) -> void:
	if paused:
		return

	var sim_delta := delta * float(speed_multiplier)
	tick_elapsed.emit(sim_delta)

	_minute_accumulator += sim_delta
	while _minute_accumulator >= SECONDS_PER_MINUTE:
		_minute_accumulator -= SECONDS_PER_MINUTE
		_advance_minute()


func get_time_of_day_normalized() -> float:
	var minute_fraction := _minute_accumulator / SECONDS_PER_MINUTE
	var total_minutes := float(hour * MINUTES_PER_HOUR + minute) + minute_fraction
	var minutes_per_day := float(HOURS_PER_DAY * MINUTES_PER_HOUR)
	return clampf(total_minutes / minutes_per_day, 0.0, 1.0)


func get_time_string() -> String:
	return LocaleService.trf("label.time.day_clock", {
		"day": day,
		"hour": "%02d" % hour,
		"minute": "%02d" % minute,
	})


func toggle_pause() -> void:
	set_paused(not paused)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	EventBus.simulation_paused_changed.emit(paused)


func to_dict() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"minute": minute,
		"paused": paused,
		"speed_multiplier": speed_multiplier,
		"minute_accumulator": _minute_accumulator,
	}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	hour = int(data.get("hour", 8))
	minute = int(data.get("minute", 0))
	paused = bool(data.get("paused", false))
	speed_multiplier = int(data.get("speed_multiplier", 1))
	if not SPEED_OPTIONS.has(speed_multiplier):
		speed_multiplier = 1
	_minute_accumulator = clampf(float(data.get("minute_accumulator", 0.0)), 0.0, SECONDS_PER_MINUTE)


func set_speed(multiplier: int) -> void:
	if not SPEED_OPTIONS.has(multiplier):
		push_warning("SimulationClock: unsupported speed x%d" % multiplier)
		return
	if speed_multiplier == multiplier:
		return
	speed_multiplier = multiplier
	EventBus.simulation_speed_changed.emit(speed_multiplier)


func _advance_minute() -> void:
	minute += 1
	if minute >= MINUTES_PER_HOUR:
		minute = 0
		_advance_hour()
	else:
		minute_changed.emit(minute)
		EventBus.time_of_day_changed.emit(get_time_of_day_normalized())


func _advance_hour() -> void:
	hour += 1
	if hour >= HOURS_PER_DAY:
		hour = 0
		day += 1
		day_changed.emit(day)

	hour_changed.emit(hour)
	minute_changed.emit(minute)
	EventBus.time_of_day_changed.emit(get_time_of_day_normalized())
