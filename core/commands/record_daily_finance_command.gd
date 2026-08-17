class_name RecordDailyFinanceCommand
extends RefCounted
## Архивация финансов завершённого дня перед сбросом дневных счётчиков.


static func execute(business_id: String, completed_day: int) -> CommandResult:
	var business := GameState.get_business(business_id)
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if completed_day < 1:
		return CommandResult.fail("Некорректный день для архивации")

	var live := FinanceHistory.get_live(business_id)
	var sales_count := live.daily_sales if live != null else business.last_tick_sales
	var missed_sales := business.daily_missed_sales

	var record := DayFinanceRecord.create(
		completed_day,
		business.daily_revenue,
		business.daily_expenses,
		sales_count,
		missed_sales,
		business.cash,
	)

	FinanceHistory.record_day(business_id, record)
	EventBus.business_day_ended.emit(business_id, record)
	EventBus.state_changed.emit()
	return CommandResult.ok()
