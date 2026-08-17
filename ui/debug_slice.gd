extends Control
## Debug: дневной спрос NPC, слайдер цены, список жителей.

const BUSINESS_ID := "bakery"
const FLOUR_ID := "flour"
const BREAD_ID := "bread"
const BUY_QUANTITY := 10

@onready var _title_label: Label = %TitleLabel
@onready var _cash_label: Label = %CashLabel
@onready var _storage_label: Label = %StorageLabel
@onready var _price_label: Label = %PriceLabel
@onready var _history_label: Label = %HistoryLabel
@onready var _last_tick_label: Label = %LastTickLabel
@onready var _npc_title: Label = %NpcTitle
@onready var _npc_list: ItemList = %NpcList
@onready var _price_slider: HSlider = %PriceSlider
@onready var _price_level_label: Label = %PriceLevelLabel
@onready var _log_label: Label = %LogLabel
@onready var _slot_name_edit: LineEdit = %SlotNameEdit
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _buy_flour_button: Button = %BuyFlourButton
@onready var _run_demand_button: Button = %RunDemandButton
@onready var _apply_costs_button: Button = %ApplyDailyCostsButton
@onready var _locale_en_button: Button = %LocaleEnButton
@onready var _locale_ru_button: Button = %LocaleRuButton

var _updating_slider := false


func _ready() -> void:
	_price_slider.min_value = DemandFormula.LEVEL_MIN
	_price_slider.max_value = DemandFormula.LEVEL_MAX
	_price_slider.step = 1.0

	EventBus.business_cash_changed.connect(_on_refresh)
	EventBus.business_storage_changed.connect(_on_refresh)
	EventBus.business_price_level_changed.connect(_on_price_level_changed)
	EventBus.business_demand_tick_completed.connect(_on_demand_tick_completed)
	EventBus.business_daily_costs_applied.connect(_on_refresh)
	EventBus.npcs_initialized.connect(_on_npcs_initialized)
	EventBus.npc_cash_changed.connect(_on_npc_changed)
	EventBus.npc_purchase_recorded.connect(_on_npc_purchase_recorded)
	EventBus.state_changed.connect(_refresh_panel)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.locale_changed.connect(_on_locale_changed)

	_slot_name_edit.text = "default"
	_apply_static_labels()
	_refresh_panel()


func _apply_static_labels() -> void:
	_title_label.text = LocaleService.trf("label.debug_slice.title")
	_npc_title.text = LocaleService.trf("label.npc.list_header")
	_slot_name_edit.placeholder_text = LocaleService.trf("label.save.slot_placeholder")
	_save_button.text = LocaleService.trf("action.save")
	_load_button.text = LocaleService.trf("action.load")
	_buy_flour_button.text = LocaleService.trf("action.buy_flour")
	_run_demand_button.text = LocaleService.trf("action.run_demand")
	_apply_costs_button.text = LocaleService.trf("action.apply_daily_costs")
	_locale_en_button.text = LocaleService.trf("action.locale.en")
	_locale_ru_button.text = LocaleService.trf("action.locale.ru")
	if _log_label.text == "Log: —" or _log_label.text.is_empty():
		_log_label.text = LocaleService.trf("label.log.placeholder")


func _on_locale_changed(_locale_code: String) -> void:
	_apply_static_labels()
	_refresh_panel()


func _on_locale_en_pressed() -> void:
	LocaleService.set_locale("en")


func _on_locale_ru_pressed() -> void:
	LocaleService.set_locale("ru")


func _on_save_pressed() -> void:
	var slot := _slot_name_edit.text.strip_edges()
	var result := SaveManager.save_game(slot)
	if result.success:
		_log_label.text = LocaleService.trf("msg.save.saved", {
			"slot": slot,
			"day": SimulationClock.day,
		})
	else:
		_log_label.text = LocaleService.trf("msg.save.fail", {"error": result.error})


func _on_load_pressed() -> void:
	var slot := _slot_name_edit.text.strip_edges()
	var result := SaveManager.load_game(slot)
	if result.success:
		_log_label.text = LocaleService.trf("msg.save.loaded", {
			"slot": slot,
			"day": SimulationClock.day,
		})
		_refresh_panel()
	else:
		_log_label.text = LocaleService.trf("msg.load.fail", {"error": result.error})


func _on_game_loaded(_slot_name: String) -> void:
	_refresh_panel()


func _on_buy_flour_pressed() -> void:
	_run_command(
		BuyResourceCommand.execute,
		[BUSINESS_ID, FLOUR_ID, BUY_QUANTITY],
	)


func _on_run_demand_pressed() -> void:
	_run_command(
		SimulateDailyDemandCommand.execute,
		[BUSINESS_ID, SimulationClock.day],
	)


func _on_apply_daily_costs_pressed() -> void:
	_run_command(ApplyDailyCostsCommand.execute, [BUSINESS_ID])


func _on_price_slider_value_changed(value: float) -> void:
	if _updating_slider:
		return
	var level := int(value)
	_update_price_level_label(level)
	_run_command(SetPriceLevelCommand.execute, [BUSINESS_ID, BREAD_ID, level])


func _on_price_level_changed(business_id: String, good_id: String, level: int) -> void:
	if business_id != BUSINESS_ID or good_id != BREAD_ID:
		return
	_updating_slider = true
	_price_slider.value = float(level)
	_update_price_level_label(level)
	_updating_slider = false
	_refresh_panel()


func _on_demand_tick_completed(
	business_id: String,
	sales_count: int,
	missed_sales_count: int,
	revenue: float,
	day: int,
) -> void:
	if business_id != BUSINESS_ID:
		return
	_log_label.text = LocaleService.trf("msg.demand.tick_debug", {
		"day": day,
		"sales": sales_count,
		"missed": missed_sales_count,
		"revenue": int(round(revenue)),
	})
	_refresh_panel()


func _on_npcs_initialized() -> void:
	_refresh_panel()


func _on_npc_changed(_npc_id: String, _cash: float) -> void:
	_refresh_npc_list()


func _on_npc_purchase_recorded(
	_npc_id: String,
	_business_id: String,
	_good_id: String,
	_outcome: int,
	_day: int,
) -> void:
	_refresh_npc_list()


func _on_refresh(business_id: String, _arg = null) -> void:
	if business_id == BUSINESS_ID:
		_refresh_panel()


func _run_command(command: Callable, args: Array) -> void:
	var result := CommandProcessor.execute(command, args)
	if result.success:
		_log_label.text = LocaleService.trf("msg.command.ok")
	else:
		_log_label.text = LocaleService.trf("msg.command.fail", {"error": result.error})


func _update_price_level_label(level: int) -> void:
	var multiplier := DemandFormula.level_to_multiplier(level)
	var percent := int(round((multiplier - 1.0) * 100.0))
	var sign := "+" if percent >= 0 else ""
	_price_level_label.text = LocaleService.trf("label.price.bread_level", {
		"level": level,
		"sign": sign,
		"percent": percent,
	})


func _refresh_panel() -> void:
	var business := GameState.get_business(BUSINESS_ID)
	if business == null:
		_cash_label.text = LocaleService.trf("label.business.not_found_short")
		return

	_cash_label.text = LocaleService.trf("label.debug.cash_summary", {
		"cash": int(round(business.cash)),
		"count": GameState.get_population(),
		"seed": GameState.simulation_seed,
	})
	_storage_label.text = LocaleService.trf(
		"label.storage.summary",
		{"summary": business.get_storage_summary()},
	)

	var level := business.get_price_level(BREAD_ID)
	_price_label.text = LocaleService.trf("label.price.bread_debug", {
		"level": level,
		"price": int(round(business.get_sale_price(BREAD_ID))),
	})
	_updating_slider = true
	_price_slider.value = float(level)
	_update_price_level_label(level)
	_updating_slider = false

	_history_label.text = LocaleService.trf("label.finance.today_summary", {
		"revenue": int(round(business.daily_revenue)),
		"expenses": int(round(business.daily_expenses)),
		"missed": business.daily_missed_sales,
	})
	_last_tick_label.text = LocaleService.trf("label.finance.last_tick", {
		"sales": business.last_tick_sales,
		"missed": business.last_tick_missed_sales,
		"revenue": int(round(business.last_tick_revenue)),
	})

	_refresh_npc_list()


func _refresh_npc_list() -> void:
	_npc_list.clear()
	_npc_list.add_item(LocaleService.trf("label.npc.table_header"))

	for npc in GameState.get_npcs_sorted():
		var last_text := _format_last_purchase(npc)
		_npc_list.add_item(
			"%s\t%s\t%.0f\t%s" % [
				npc.id,
				DataRegistry.get_npc_archetype_name(npc.archetype_id),
				npc.cash,
				last_text,
			]
		)


func _format_last_purchase(npc: NpcState) -> String:
	if npc.last_purchase_day <= 0:
		return LocaleService.trf("label.common.dash")

	var status := LocaleService.trf("label.npc.purchase_ok") if npc.last_purchase_success else npc.last_purchase_note
	if npc.last_purchase_good_id.is_empty():
		return "D%d %s" % [npc.last_purchase_day, status]

	return LocaleService.trf("label.npc.last_purchase", {
		"day": npc.last_purchase_day,
		"good": DataRegistry.get_good_name(npc.last_purchase_good_id),
		"business": npc.last_purchase_business_id,
		"status": status,
	})
