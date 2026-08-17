class_name SetPriceLevelCommand
extends RefCounted
## Установка уровня цены 0–10 (0 = −50% базы, 10 = +100% к базе).


static func execute(business_id: String, good_id: String, level: int) -> CommandResult:
	var business := GameState.get_business(business_id)
	var validation := _validate(business, good_id, level)
	if not validation.success:
		return validation

	var clamped := DemandFormula.clamp_level(level)
	business.price_levels[good_id] = clamped
	business.prices[good_id] = business.get_sale_price(good_id)

	EventBus.business_price_level_changed.emit(business_id, good_id, clamped)
	EventBus.business_price_changed.emit(
		business_id,
		good_id,
		float(business.prices[good_id]),
	)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(
	business: BusinessState,
	good_id: String,
	level: int,
) -> CommandResult:
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if good_id.is_empty():
		return CommandResult.fail("Не указан товар")
	if DataRegistry.get_good(good_id) == null:
		return CommandResult.fail("Неизвестный товар: %s" % good_id)
	if not BusinessEconomy.is_allowed_good(business, good_id):
		return CommandResult.fail("Товар не разрешён для продажи")
	if level < DemandFormula.LEVEL_MIN or level > DemandFormula.LEVEL_MAX:
		return CommandResult.fail(
			"Уровень цены вне диапазона (%d–%d)" % [
				DemandFormula.LEVEL_MIN,
				DemandFormula.LEVEL_MAX,
			]
		)
	return CommandResult.ok()
