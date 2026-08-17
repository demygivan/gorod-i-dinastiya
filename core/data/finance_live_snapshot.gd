class_name FinanceLiveSnapshot
extends RefCounted
## Read-модель «сегодня» для debug UI. Обновляется только через FinanceHistory.


var business_id: String = ""
var game_day: int = 1
var cash: float = 0.0
var storage: Dictionary = {}       ## good_id -> int
var price_levels: Dictionary = {} ## good_id -> int
var prices: Dictionary = {}         ## good_id -> float
var daily_revenue: float = 0.0
var daily_expenses: float = 0.0
var daily_sales: int = 0
var daily_missed_sales: int = 0
var player_reputation: float = 50.0
var player_reputation_demand_mult: float = 1.0


func get_net_profit() -> float:
	return daily_revenue - daily_expenses


func duplicate_storage() -> Dictionary:
	return storage.duplicate()


func duplicate_price_levels() -> Dictionary:
	return price_levels.duplicate()


func duplicate_prices() -> Dictionary:
	return prices.duplicate()
