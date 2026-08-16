class_name CityData
extends Resource
## Городские параметры (0-100), плюс производные величины.

@export_range(0, 100) var safety: float = 50.0
@export_range(0, 100) var discrimination: float = 20.0
@export_range(0, 100) var corruption: float = 20.0
@export_range(0, 100) var democracy: float = 50.0
@export_range(0, 100) var unemployment: float = 10.0

@export var population: int = 0

# Производные — не редактируются вручную, пересчитываются CityStatsSystem
var crime_rate: float = 0.0
var criminals: int = 0
