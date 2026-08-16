extends Node
## Автозагрузка "GameClock". Единственный источник игрового времени.
## Остальные системы подписываются на сигналы, а не опрашивают время сами.

signal hour_passed(hour: int)
signal day_passed(day: int)
signal season_passed(season: int)
signal year_passed(year: int)

@export var seconds_per_hour: float = 1.0  ## Реальные секунды на 1 игровой час
@export var days_per_season: int = 30
@export var seasons_per_year: int = 4

var paused: bool = false

var hour: int = 0
var day: int = 1
var season: int = 0
var year: int = 1

var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta
	if _accumulator >= seconds_per_hour:
		_accumulator = 0.0
		_advance_hour()


func set_paused(value: bool) -> void:
	paused = value


func _advance_hour() -> void:
	hour += 1
	hour_passed.emit(hour)
	if hour >= 24:
		hour = 0
		_advance_day()


func _advance_day() -> void:
	day += 1
	day_passed.emit(day)
	if day > days_per_season:
		day = 1
		_advance_season()


func _advance_season() -> void:
	season += 1
	season_passed.emit(season)
	if season >= seasons_per_year:
		season = 0
		_advance_year()


func _advance_year() -> void:
	year += 1
	year_passed.emit(year)
