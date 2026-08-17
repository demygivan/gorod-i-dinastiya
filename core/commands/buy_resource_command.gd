class_name BuyResourceCommand
extends RefCounted
## Закупка товара на склад предприятия (пока без NPC-рынка, по base_price).


static func execute(business_id: String, good_id: String, quantity: int) -> CommandResult:
	var business := GameState.get_business(business_id)
	var validation := _validate(business, good_id, quantity)
	if not validation.success:
		return validation

	var cost := BusinessEconomy.get_purchase_cost(good_id, quantity)
	business.cash -= cost
	business.storage[good_id] = BusinessEconomy.get_storage_quantity(business, good_id) + quantity

	EventBus.business_cash_changed.emit(business_id, business.cash)
	EventBus.business_storage_changed.emit(
		business_id,
		good_id,
		int(business.storage[good_id]),
	)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(
	business: BusinessState,
	good_id: String,
	quantity: int,
) -> CommandResult:
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if good_id.is_empty():
		return CommandResult.fail("Не указан товар")
	if quantity <= 0:
		return CommandResult.fail("Количество должно быть больше 0")
	if DataRegistry.get_good(good_id) == null:
		return CommandResult.fail("Неизвестный товар: %s" % good_id)
	if not BusinessEconomy.is_allowed_good(business, good_id):
		return CommandResult.fail("Товар не разрешён для этого типа бизнеса")

	var cost := BusinessEconomy.get_purchase_cost(good_id, quantity)
	if business.cash < cost:
		return CommandResult.fail(
			"Недостаточно денег (нужно %.0f, есть %.0f)" % [cost, business.cash]
		)

	return BusinessEconomy.can_add_to_storage(business, good_id, quantity)
