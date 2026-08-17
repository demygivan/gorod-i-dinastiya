class_name ApplyDailyCostsCommand
extends RefCounted
## Списание дневных издержек предприятия из BusinessTypeDefinition.


static func execute(business_id: String) -> CommandResult:
	var business := GameState.get_business(business_id)
	var validation := _validate(business)
	if not validation.success:
		return validation

	var business_type := BusinessEconomy.get_type_definition(business)
	var base_cost := business_type.base_daily_cost
	var effect_day := maxi(SimulationClock.day - 1, 1)
	var tax_mult := LawEffects.get_daily_cost_multiplier(GameState.laws, effect_day)
	var cost := base_cost * tax_mult

	business.cash -= cost
	business.daily_expenses += cost

	EventBus.business_cash_changed.emit(business_id, business.cash)
	EventBus.business_daily_costs_applied.emit(business_id, cost)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(business: BusinessState) -> CommandResult:
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if BusinessEconomy.get_type_definition(business) == null:
		return CommandResult.fail("Тип предприятия не найден")
	return CommandResult.ok()
