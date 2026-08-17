class_name SetPriceCommand
extends RefCounted
## Установка текущей цены продажи товара предприятия.


static func execute(business_id: String, good_id: String, new_price: float) -> CommandResult:
	var business := GameState.get_business(business_id)
	var validation := _validate(business, good_id, new_price)
	if not validation.success:
		return validation

	business.prices[good_id] = new_price
	EventBus.business_price_changed.emit(business_id, good_id, new_price)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(
	business: BusinessState,
	good_id: String,
	new_price: float,
) -> CommandResult:
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if good_id.is_empty():
		return CommandResult.fail("Не указан товар")
	if not BusinessEconomy.is_allowed_good(business, good_id):
		return CommandResult.fail("Товар не разрешён для продажи")

	var price_validation := BusinessEconomy.validate_price(good_id, new_price)
	if not price_validation.success:
		return price_validation

	return CommandResult.ok()
