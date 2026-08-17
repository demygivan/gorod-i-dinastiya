class_name DayFinanceRecord
extends Resource
## Агрегат финансов одного бизнеса за завершённый игровой день.


@export var day: int = 0
@export var revenue: float = 0.0
@export var expenses: float = 0.0
@export var profit: float = 0.0
@export var sales_count: int = 0
@export var missed_sales: int = 0
@export var cash_end_of_day: float = 0.0


static func create(
	p_day: int,
	p_revenue: float,
	p_expenses: float,
	p_sales_count: int,
	p_missed_sales: int,
	p_cash: float,
) -> DayFinanceRecord:
	var record := DayFinanceRecord.new()
	record.day = p_day
	record.revenue = p_revenue
	record.expenses = p_expenses
	record.profit = p_revenue - p_expenses
	record.sales_count = p_sales_count
	record.missed_sales = p_missed_sales
	record.cash_end_of_day = p_cash
	return record


func to_dict() -> Dictionary:
	return {
		"day": day,
		"revenue": revenue,
		"expenses": expenses,
		"profit": profit,
		"sales_count": sales_count,
		"missed_sales": missed_sales,
		"cash_end_of_day": cash_end_of_day,
	}


static func from_dict(data: Dictionary) -> DayFinanceRecord:
	var record := DayFinanceRecord.new()
	record.day = int(data.get("day", 0))
	record.revenue = float(data.get("revenue", 0.0))
	record.expenses = float(data.get("expenses", 0.0))
	record.profit = float(data.get("profit", 0.0))
	record.sales_count = int(data.get("sales_count", 0))
	record.missed_sales = int(data.get("missed_sales", 0))
	record.cash_end_of_day = float(data.get("cash_end_of_day", 0.0))
	return record
