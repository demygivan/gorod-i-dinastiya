class_name CityStatsSystem
extends RefCounted
## Пересчёт производных городских параметров. Вызывать раз в сезон
## (подписка на GameClock.season_passed).

static func recalculate_crime_rate(city: CityData) -> void:
	var rate: float = (100.0 - city.safety) * 0.4 \
		+ city.corruption * 0.3 \
		+ city.discrimination * 0.2 \
		+ city.unemployment * 0.1

	city.crime_rate = clamp(rate, 0.0, 100.0)
	city.criminals = int(city.population * city.crime_rate / 100.0)

	EventBus.city_stats_changed.emit()
