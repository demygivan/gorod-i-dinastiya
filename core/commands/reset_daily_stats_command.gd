class_name ResetDailyStatsCommand
extends RefCounted
## Сброс дневных счётчиков выручки и расходов (начало нового игрового дня).


static func execute(business_id: String) -> CommandResult:
	var business := GameState.get_business(business_id)
	if business == null:
		return CommandResult.fail("Предприятие не найдено")

	business.daily_revenue = 0.0
	business.daily_expenses = 0.0
	business.daily_missed_sales = 0
	EventBus.state_changed.emit()
	return CommandResult.ok()
