extends Node
## Сигналы изменений состояния. Системы и UI подписываются, не вызывают друг друга напрямую.

signal business_price_changed(business_id: String, good_id: String, new_price: float)
signal business_price_level_changed(business_id: String, good_id: String, level: int)
signal business_cash_changed(business_id: String, new_cash: float)
signal business_storage_changed(business_id: String, good_id: String, new_quantity: int)
signal business_daily_costs_applied(business_id: String, amount: float)
signal business_demand_tick_completed(
	business_id: String,
	sales_count: int,
	missed_sales_count: int,
	revenue: float,
	day: int,
)
signal business_day_ended(business_id: String, record: DayFinanceRecord)
signal npcs_initialized()
signal npc_cash_changed(npc_id: String, new_cash: float)
signal npc_purchase_recorded(
	npc_id: String,
	business_id: String,
	good_id: String,
	outcome: int,
	day: int,
)
signal npc_shopping_visit(npc_id: String, business_id: String)
signal npc_positions_changed()
signal characters_initialized()
signal character_positions_changed()
signal character_path_changed(character_id: String, target_cell: Vector2i)
signal character_arrived(character_id: String, cell: Vector2i)
signal reputation_changed(owner_id: String, new_value: float, delta_applied: float)
signal council_vote_completed(
	law_id: String,
	passed: bool,
	votes_for: int,
	votes_against: int,
	day: int,
)
signal law_activated(law_id: String, activated_day: int, expires_day: int)
signal law_expired(law_id: String, day: int)
signal law_campaign_applied(business_id: String, amount: float, npcs_affected: int)
signal game_loaded(slot_name: String)
signal locale_changed(locale_code: String)
signal business_selected(business_id: String)
signal state_changed()

signal simulation_paused_changed(is_paused: bool)
signal simulation_speed_changed(multiplier: int)
signal time_of_day_changed(normalized: float)
