extends Node
## Автозагрузка "EventBus". Системы общаются через сигналы, а не через
## прямые вызовы друг друга — это сильно упрощает добавление новых фич
## (например, UI просто подписывается на нужные сигналы).

signal character_arrested(character_id: String)
signal character_released(character_id: String)
signal character_died(character_id: String)
signal character_born(character_id: String, family_id: String)

signal building_produced(building_id: String, resource: String, amount: int)
signal building_price_changed(building_id: String, new_price: int)
signal character_hired(character_id: String, building_id: String)
signal theft_attempted(thief_id: String, target_id: String, success: bool)

signal city_stats_changed()
