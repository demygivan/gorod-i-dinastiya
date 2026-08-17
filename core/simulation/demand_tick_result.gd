class_name DemandTickResult
extends RefCounted
## Результат одного дневного тика спроса (без мутаций состояния).

var raw_demand: Dictionary = {}       ## good_id -> int
var intended_purchases: Dictionary = {} ## good_id -> int
var sales_by_good: Dictionary = {}    ## good_id -> int
var missed_by_good: Dictionary = {}   ## good_id -> int
var revenue_by_good: Dictionary = {}  ## good_id -> float

var total_sales: int = 0
var total_missed: int = 0
var total_revenue: float = 0.0


func add_good_result(
	good_id: String,
	raw_qty: int,
	intended_qty: int,
	sold_qty: int,
	revenue: float,
) -> void:
	if raw_qty > 0:
		raw_demand[good_id] = raw_qty
	if intended_qty > 0:
		intended_purchases[good_id] = intended_qty
	if sold_qty > 0:
		sales_by_good[good_id] = int(sales_by_good.get(good_id, 0)) + sold_qty
	var missed_qty := intended_qty - sold_qty
	if missed_qty > 0:
		missed_by_good[good_id] = int(missed_by_good.get(good_id, 0)) + missed_qty
	if revenue > 0.0:
		revenue_by_good[good_id] = float(revenue_by_good.get(good_id, 0.0)) + revenue

	total_sales += sold_qty
	total_missed += missed_qty
	total_revenue += revenue
