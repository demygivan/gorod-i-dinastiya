extends CanvasModulate
## Визуальное время суток — только отображение, читает SimulationClock.

const NIGHT := Color(0.45, 0.5, 0.75, 1.0)
const DAWN := Color(1.0, 0.82, 0.65, 1.0)
const DAY := Color(1.0, 1.0, 1.0, 1.0)
const DUSK := Color(1.0, 0.75, 0.55, 1.0)


func _ready() -> void:
	SimulationClock.hour_changed.connect(_on_hour_changed)
	SimulationClock.tick_elapsed.connect(_on_tick_elapsed)
	_apply_normalized(SimulationClock.get_time_of_day_normalized())


func _on_hour_changed(_hour: int) -> void:
	_apply_normalized(SimulationClock.get_time_of_day_normalized())


func _on_tick_elapsed(_sim_delta: float) -> void:
	_apply_normalized(SimulationClock.get_time_of_day_normalized())


func _apply_normalized(t: float) -> void:
	color = _color_for_time(t)


func _color_for_time(t: float) -> Color:
	# t: 0.0 = полночь, 0.5 = полдень
	if t < 0.2:
		return NIGHT.lerp(DAWN, t / 0.2)
	if t < 0.35:
		return DAWN.lerp(DAY, (t - 0.2) / 0.15)
	if t < 0.65:
		return DAY
	if t < 0.8:
		return DAY.lerp(DUSK, (t - 0.65) / 0.15)
	return DUSK.lerp(NIGHT, (t - 0.8) / 0.2)
