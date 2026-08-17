extends CanvasLayer
## HUD: время, экономика выбранного предприятия, слайдер цены 0–10.

const DEFAULT_BUSINESS_ID := "bakery"
const FLOUR_ID := "flour"
const BREAD_ID := "bread"
const BUY_QUANTITY := 10

@onready var _time_label: Label = %TimeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _business_label: Label = %BusinessLabel
@onready var _cash_label: Label = %CashLabel
@onready var _storage_label: Label = %StorageLabel
@onready var _price_label: Label = %PriceLabel
@onready var _daily_label: Label = %DailyLabel
@onready var _last_tick_label: Label = %LastTickLabel
@onready var _price_slider: HSlider = %PriceSlider
@onready var _price_level_label: Label = %PriceLevelLabel
@onready var _goods_list: ItemList = %GoodsList
@onready var _demand_title: Label = %DemandTitle
@onready var _demand_list: ItemList = %DemandList
@onready var _pause_button: Button = %PauseButton
@onready var _action_log_label: Label = %ActionLogLabel
@onready var _buy_flour_button: Button = %BuyFlourButton

var _selected_business_id: String = ""
var _updating_slider := false


func _ready() -> void:
	EventBus.business_selected.connect(_on_business_selected)
	EventBus.business_price_level_changed.connect(_on_business_price_level_changed)
	EventBus.business_cash_changed.connect(_on_business_economy_changed)
	EventBus.business_storage_changed.connect(_on_business_economy_changed)
	EventBus.business_demand_tick_completed.connect(_on_business_demand_tick_completed)
	EventBus.business_daily_costs_applied.connect(_on_business_economy_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.simulation_paused_changed.connect(_on_simulation_paused_changed)
	EventBus.simulation_speed_changed.connect(_on_simulation_speed_changed)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.npcs_initialized.connect(_on_npcs_initialized)
	EventBus.game_loaded.connect(_on_npcs_initialized)
	SimulationClock.minute_changed.connect(_on_time_changed)
	SimulationClock.hour_changed.connect(_on_time_changed)
	SimulationClock.day_changed.connect(_on_time_changed)

	_price_slider.min_value = DemandFormula.LEVEL_MIN
	_price_slider.max_value = DemandFormula.LEVEL_MAX
	_price_slider.step = 1.0

	_apply_static_labels()
	_populate_goods_catalog()
	_refresh_demand_table()
	_refresh_time_label()
	_refresh_status_label()
	_select_default_business()


func _on_locale_changed(_locale_code: String) -> void:
	_apply_static_labels()
	_populate_goods_catalog()
	_refresh_demand_table()
	_refresh_time_label()
	_refresh_status_label()
	_refresh_business_panel()


func _on_npcs_initialized() -> void:
	_refresh_demand_table()


func _apply_static_labels() -> void:
	var goods_title := get_node_or_null("GoodsPanel/VBox/GoodsTitle")
	if goods_title is Label:
		goods_title.text = LocaleService.trf("label.hud.goods_title")
	_demand_title.text = LocaleService.trf("label.hud.demand_title")
	_pause_button.text = LocaleService.trf("action.resume") if SimulationClock.paused else LocaleService.trf("action.pause")
	_buy_flour_button.text = LocaleService.trf("action.buy_flour")
	_action_log_label.text = LocaleService.trf("label.hud.demand_hint")


func _select_default_business() -> void:
	if GameState.get_business(DEFAULT_BUSINESS_ID) != null:
		EventBus.business_selected.emit(DEFAULT_BUSINESS_ID)
	elif not GameState.businesses.is_empty():
		EventBus.business_selected.emit(str(GameState.businesses.keys()[0]))
	else:
		_refresh_business_panel()


func _populate_goods_catalog() -> void:
	_goods_list.clear()
	var last_category := ""

	for good in DataRegistry.get_goods():
		if good.category != last_category:
			last_category = good.category
			var header_index := _goods_list.add_item(
				LocaleService.trf(
					"label.goods.category_header",
					{"name": DataRegistry.get_category_name(good.category)},
				)
			)
			_goods_list.set_item_custom_fg_color(header_index, Color(0.55, 0.55, 0.55))
			_goods_list.set_item_selectable(header_index, false)
			_goods_list.set_item_disabled(header_index, true)

		var recipe := DataRegistry.format_recipe_suffix(good)
		_goods_list.add_item(
			LocaleService.trf("label.goods.catalog_item", {
				"name": DataRegistry.get_good_name(good.id),
				"price": int(round(good.base_price)),
				"recipe": recipe,
			})
		)


func _refresh_demand_table() -> void:
	_demand_list.clear()
	_demand_list.add_item(LocaleService.trf("label.hud.demand_header"))

	var entries := DemandAggregator.get_sorted_demand_entries(GameState.get_npcs_sorted())
	if entries.is_empty():
		_demand_list.add_item(LocaleService.trf("label.hud.demand_empty"))
		return

	for entry in entries:
		var good_id: String = str(entry.get("good_id", ""))
		var quantity: int = int(entry.get("quantity", 0))
		_demand_list.add_item(LocaleService.trf("label.hud.demand_row", {
			"name": DataRegistry.get_good_name(good_id),
			"qty": quantity,
		}))


func _on_pause_pressed() -> void:
	SimulationClock.toggle_pause()


func _on_speed_pressed(multiplier: int) -> void:
	SimulationClock.set_speed(multiplier)


func _on_buy_flour_pressed() -> void:
	if _selected_business_id.is_empty():
		return
	_run_command(
		BuyResourceCommand.execute,
		[_selected_business_id, FLOUR_ID, BUY_QUANTITY],
	)


func _on_price_slider_value_changed(value: float) -> void:
	if _updating_slider or _selected_business_id.is_empty():
		return

	var level := int(value)
	_update_price_level_label(level)
	_run_command(
		SetPriceLevelCommand.execute,
		[_selected_business_id, BREAD_ID, level],
	)


func _on_business_selected(business_id: String) -> void:
	_selected_business_id = business_id
	_refresh_business_panel()


func _on_business_price_level_changed(
	business_id: String,
	good_id: String,
	level: int,
) -> void:
	if business_id != _selected_business_id or good_id != BREAD_ID:
		return
	_sync_slider(level)
	_refresh_business_panel()


func _on_business_economy_changed(business_id: String, _arg = null) -> void:
	if business_id == _selected_business_id:
		_refresh_business_panel()


func _on_business_demand_tick_completed(
	business_id: String,
	sales_count: int,
	missed_sales_count: int,
	revenue: float,
	day: int,
) -> void:
	if business_id != _selected_business_id:
		return

	_action_log_label.text = LocaleService.trf("msg.demand.day_result", {
		"day": day,
		"sales": sales_count,
		"missed": missed_sales_count,
		"revenue": int(round(revenue)),
	})
	_refresh_business_panel()


func _on_state_changed() -> void:
	_refresh_business_panel()


func _on_simulation_paused_changed(is_paused: bool) -> void:
	_pause_button.text = LocaleService.trf("action.resume") if is_paused else LocaleService.trf("action.pause")
	_refresh_status_label()


func _on_simulation_speed_changed(_multiplier: int) -> void:
	_refresh_status_label()


func _on_time_changed(_value: int = 0) -> void:
	_refresh_time_label()


func _run_command(command: Callable, args: Array) -> void:
	var result := CommandProcessor.execute(command, args)
	if result.success:
		_action_log_label.text = LocaleService.trf("msg.command.ok")
	else:
		_action_log_label.text = LocaleService.trf("msg.command.fail", {"error": result.error})


func _sync_slider(level: int) -> void:
	_updating_slider = true
	_price_slider.value = float(level)
	_update_price_level_label(level)
	_updating_slider = false


func _update_price_level_label(level: int) -> void:
	var multiplier := DemandFormula.level_to_multiplier(level)
	var percent := int(round((multiplier - 1.0) * 100.0))
	var sign := "+" if percent >= 0 else ""
	_price_level_label.text = LocaleService.trf("label.price.bread_level", {
		"level": level,
		"sign": sign,
		"percent": percent,
	})


func _refresh_time_label() -> void:
	_time_label.text = "%s %s" % [
		SimulationClock.get_time_string(),
		LocaleService.trf("label.time.npcs_suffix", {"count": GameState.get_population()}),
	]


func _refresh_status_label() -> void:
	var state_text := LocaleService.trf(
		"label.simulation.paused" if SimulationClock.paused else "label.simulation.running"
	)
	_status_label.text = LocaleService.trf("label.simulation.status", {
		"state": state_text,
		"speed": SimulationClock.speed_multiplier,
	})


func _refresh_business_panel() -> void:
	if _selected_business_id.is_empty():
		_business_label.text = LocaleService.trf("label.business.click_building")
		_cash_label.text = LocaleService.trf("label.cash.na")
		_storage_label.text = LocaleService.trf("label.storage.na")
		_price_label.text = LocaleService.trf("label.price.na")
		_daily_label.text = LocaleService.trf("label.finance.today_na")
		_last_tick_label.text = LocaleService.trf("label.finance.last_tick_na")
		return

	var business := GameState.get_business(_selected_business_id)
	if business == null:
		_business_label.text = LocaleService.trf("label.business.not_found")
		return

	_business_label.text = LocaleService.trf(
		"label.business.title",
		{"name": business.get_display_name()},
	)
	_cash_label.text = LocaleService.trf("label.cash.amount", {"amount": int(round(business.cash))})
	_storage_label.text = LocaleService.trf(
		"label.storage.summary",
		{"summary": business.get_storage_summary()},
	)

	var lines: PackedStringArray = []
	for good_id in business.price_levels.keys():
		var level := business.get_price_level(str(good_id))
		var sale_price := business.get_sale_price(str(good_id))
		var good_name := DataRegistry.get_good_name(str(good_id))
		var base_price := int(round(DataRegistry.get_good_price(str(good_id))))
		lines.append(LocaleService.trf("label.price.good_line", {
			"name": good_name,
			"level": level,
			"price": int(round(sale_price)),
			"base": base_price,
		}))

	_price_label.text = "\n".join(lines) if not lines.is_empty() else LocaleService.trf("label.price.na")
	_daily_label.text = LocaleService.trf("label.finance.today_summary", {
		"revenue": int(round(business.daily_revenue)),
		"expenses": int(round(business.daily_expenses)),
		"missed": business.daily_missed_sales,
	})
	_last_tick_label.text = LocaleService.trf("label.finance.last_tick", {
		"sales": business.last_tick_sales,
		"missed": business.last_tick_missed_sales,
		"revenue": int(round(business.last_tick_revenue)),
	})

	if business.price_levels.has(BREAD_ID):
		_sync_slider(business.get_price_level(BREAD_ID))
