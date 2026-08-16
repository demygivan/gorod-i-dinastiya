class_name SetBuildingPriceCommand
extends RefCounted
## Пример команды с валидацией диапазона. Та же схема годится для
## SellGoods, BuyResource, VoteOnLaw, CampaignAction и т.д. — см. GAME_SPEC.md §9.

const MIN_PRICE := 1
const MAX_PRICE := 999


static func execute(building_id: String, new_price: int) -> CommandResult:
	var building := GameState.get_building(building_id)

	var validation := _validate(building, new_price)
	if not validation.success:
		return validation

	building.price = new_price
	EventBus.building_price_changed.emit(building.id, new_price)
	return CommandResult.ok()


static func _validate(building: BuildingData, new_price: int) -> CommandResult:
	if building == null:
		return CommandResult.fail("Здание не найдено")
	if new_price < MIN_PRICE or new_price > MAX_PRICE:
		return CommandResult.fail("Цена вне допустимого диапазона (%d-%d)" % [MIN_PRICE, MAX_PRICE])
	return CommandResult.ok()
