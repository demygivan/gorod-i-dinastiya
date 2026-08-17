class_name BusinessEconomy
extends RefCounted
## Чистая экономическая логика предприятия. Без мутаций GameState.

const MIN_PRICE := 1.0
const MAX_PRICE := 999.0
const DEFAULT_STARTING_GOOD_QUANTITY := 10


static func get_type_definition(business: BusinessState) -> BusinessTypeDefinition:
	if business == null or business.type_id.is_empty():
		return null
	return DataRegistry.get_business_type(business.type_id)


static func is_allowed_good(business: BusinessState, good_id: String) -> bool:
	var business_type := get_type_definition(business)
	if business_type == null:
		return false
	return business_type.allowed_goods.has(good_id)


static func get_storage_total(business: BusinessState) -> int:
	var total := 0
	for good_id in business.storage:
		total += int(business.storage.get(good_id, 0))
	return total


static func get_storage_quantity(business: BusinessState, good_id: String) -> int:
	return int(business.storage.get(good_id, 0))


static func get_purchase_cost(good_id: String, quantity: int) -> float:
	var unit_price := DataRegistry.get_good_price(good_id)
	return unit_price * float(quantity)


static func can_add_to_storage(
	business: BusinessState,
	good_id: String,
	quantity: int,
) -> CommandResult:
	var business_type := get_type_definition(business)
	if business_type == null:
		return CommandResult.fail("Тип предприятия не найден")

	var good := DataRegistry.get_good(good_id)
	if good == null:
		return CommandResult.fail("Неизвестный товар: %s" % good_id)

	var current_total := get_storage_total(business)
	if current_total + quantity > business_type.storage_capacity:
		return CommandResult.fail(
			"Склад переполнен (лимит %d, будет %d)" % [
				business_type.storage_capacity,
				current_total + quantity,
			]
		)

	var current_good_qty := get_storage_quantity(business, good_id)
	if current_good_qty + quantity > good.max_stack:
		return CommandResult.fail(
			"Превышен лимит стека для \"%s\" (max %d)" % [
				DataRegistry.get_good_name(good_id),
				good.max_stack,
			]
		)

	return CommandResult.ok()


static func is_sellable_good(good_id: String) -> bool:
	var good := DataRegistry.get_good(good_id)
	if good == null:
		return false
	return not good.is_primary()


static func get_sellable_goods_for_business(business: BusinessState) -> Array[String]:
	var result: Array[String] = []
	if business == null:
		return result

	var business_type := get_type_definition(business)
	if business_type == null:
		return result

	for good_id in business_type.allowed_goods:
		if is_sellable_good(str(good_id)):
			result.append(str(good_id))
	return result


static func validate_price(good_id: String, new_price: float) -> CommandResult:
	if DataRegistry.get_good(good_id) == null:
		return CommandResult.fail("Неизвестный товар: %s" % good_id)
	if new_price < MIN_PRICE or new_price > MAX_PRICE:
		return CommandResult.fail(
			"Цена вне допустимого диапазона (%.0f-%.0f)" % [MIN_PRICE, MAX_PRICE]
		)
	return CommandResult.ok()
