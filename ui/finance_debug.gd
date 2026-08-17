extends Control
## Debug finance panel: read-only через FinanceHistory + EventBus.


const BUSINESS_ID := "bakery"
const _ROOT := "MarginContainer/RootVBox"
const _LEFT := "MarginContainer/RootVBox/BodySplit/LeftPanel"
const _RIGHT := "MarginContainer/RootVBox/BodySplit/RightPanel"

@onready var _day_label: Label = %DayLabel
@onready var _cash_label: Label = %CashLabel
@onready var _revenue_label: Label = %RevenueLabel
@onready var _expenses_label: Label = %ExpensesLabel
@onready var _profit_label: Label = %ProfitLabel
@onready var _sales_label: Label = %SalesLabel
@onready var _missed_label: Label = %MissedLabel
@onready var _reputation_label: Label = %ReputationLabel
@onready var _reputation_mult_label: Label = %ReputationMultLabel
@onready var _cost_mult_label: Label = %CostMultLabel
@onready var _proposed_law_label: Label = %ProposedLawLabel
@onready var _last_vote_label: Label = %LastVoteLabel
@onready var _active_laws_label: Label = %ActiveLawsLabel
@onready var _next_vote_label: Label = %NextVoteLabel
@onready var _storage_list: ItemList = %StorageList
@onready var _prices_list: ItemList = %PricesList
@onready var _history_list: ItemList = %HistoryList
@onready var _campaign_button: Button = %CampaignButton


func _ready() -> void:
	FinanceHistory.finance_live_updated.connect(_on_finance_live_updated)
	FinanceHistory.finance_history_updated.connect(_on_finance_history_updated)
	PoliticsHistory.politics_updated.connect(_on_politics_updated)
	SimulationClock.day_changed.connect(_on_clock_day_changed)
	SimulationClock.hour_changed.connect(_on_clock_hour_changed)
	SimulationClock.minute_changed.connect(_on_clock_minute_changed)
	EventBus.locale_changed.connect(_on_locale_changed)

	_apply_static_labels()
	_render_live(FinanceHistory.get_live(BUSINESS_ID))
	_render_history(FinanceHistory.get_history(BUSINESS_ID))
	_render_politics()


func _on_locale_changed(_locale_code: String) -> void:
	_apply_static_labels()
	_render_live(FinanceHistory.get_live(BUSINESS_ID))
	_render_history(FinanceHistory.get_history(BUSINESS_ID))
	_render_politics()


func _apply_static_labels() -> void:
	_get_label("%s/HeaderLabel" % _ROOT).text = LocaleService.trf("label.finance_debug.title")
	_get_label("%s/TodayTitle" % _LEFT).text = LocaleService.trf("label.finance.today")
	_get_label("%s/SummaryGrid/RevenueCaption" % _LEFT).text = LocaleService.trf("label.finance.revenue")
	_get_label("%s/SummaryGrid/ExpensesCaption" % _LEFT).text = LocaleService.trf("label.finance.expenses")
	_get_label("%s/SummaryGrid/ProfitCaption" % _LEFT).text = LocaleService.trf("label.finance.net_profit")
	_get_label("%s/SummaryGrid/SalesCaption" % _LEFT).text = LocaleService.trf("label.finance.sales")
	_get_label("%s/SummaryGrid/MissedCaption" % _LEFT).text = LocaleService.trf("label.finance.missed_sales")
	_get_label("%s/SummaryGrid/ReputationCaption" % _LEFT).text = LocaleService.trf("label.reputation.title")
	_get_label("%s/SummaryGrid/ReputationMultCaption" % _LEFT).text = LocaleService.trf("label.reputation.demand_mult")
	_get_label("%s/SummaryGrid/CostMultCaption" % _LEFT).text = LocaleService.trf("label.politics.cost_mult")
	_get_label("%s/PoliticsTitle" % _LEFT).text = LocaleService.trf("label.politics.section_title")
	_get_label("%s/StorageTitle" % _LEFT).text = LocaleService.trf("label.finance_debug.storage_title")
	_get_label("%s/PricesTitle" % _RIGHT).text = LocaleService.trf("label.finance_debug.prices_title")
	_get_label("%s/HistoryTitle" % _RIGHT).text = LocaleService.trf("label.finance_debug.history_title")
	_get_label("%s/HintLabel" % _ROOT).text = LocaleService.trf("label.finance_debug.hint")
	_campaign_button.text = LocaleService.trf("action.campaign.law")


func _get_label(path: String) -> Label:
	return get_node(path) as Label


func _on_politics_updated() -> void:
	_render_politics()


func _on_finance_live_updated(business_id: String) -> void:
	if business_id == BUSINESS_ID:
		_render_live(FinanceHistory.get_live(BUSINESS_ID))


func _on_finance_history_updated(business_id: String) -> void:
	if business_id == BUSINESS_ID:
		_render_history(FinanceHistory.get_history(BUSINESS_ID))


func _on_clock_day_changed(_day: int) -> void:
	_update_clock_label()


func _on_clock_hour_changed(_hour: int) -> void:
	_update_clock_label()


func _on_clock_minute_changed(_minute: int) -> void:
	_update_clock_label()


func _update_clock_label() -> void:
	_day_label.text = SimulationClock.get_time_string()


func _on_campaign_pressed() -> void:
	var result := CommandProcessor.execute(
		CampaignForLawCommand.execute,
		[BUSINESS_ID, CampaignForLawCommand.DEFAULT_COST],
	)
	if not result.success:
		_last_vote_label.text = LocaleService.trf("msg.campaign.fail", {"error": result.error})


func _render_politics() -> void:
	var proposed_name := DataRegistry.get_law_name(PoliticsHistory.proposed_law_id)
	_proposed_law_label.text = LocaleService.trf("label.politics.proposed", {
		"id": PoliticsHistory.proposed_law_id,
		"name": proposed_name,
	})
	_last_vote_label.text = LocaleService.trf("label.politics.last_vote", {
		"summary": PoliticsHistory.last_vote_summary,
	})
	_active_laws_label.text = LocaleService.trf("label.politics.active_laws", {
		"laws": "\n".join(PoliticsHistory.active_law_summaries),
	})
	if PoliticsHistory.next_vote_day > 0:
		_next_vote_label.text = LocaleService.trf("label.politics.next_vote", {
			"day": PoliticsHistory.next_vote_day,
		})
	else:
		_next_vote_label.text = LocaleService.trf("label.politics.next_vote_none")
	_cost_mult_label.text = LocaleService.trf("label.politics.cost_mult_value", {
		"mult": PoliticsHistory.daily_cost_multiplier,
	})


func _render_live(live: FinanceLiveSnapshot) -> void:
	_update_clock_label()

	if live == null:
		_cash_label.text = LocaleService.trf("label.cash.na")
		return

	_cash_label.text = LocaleService.trf("label.cash.amount", {"amount": int(round(live.cash))})
	_revenue_label.text = "%.0f" % live.daily_revenue
	_expenses_label.text = "%.0f" % live.daily_expenses

	var profit := live.get_net_profit()
	var profit_sign := "+" if profit >= 0.0 else ""
	_profit_label.text = "%s%.0f" % [profit_sign, profit]
	_profit_label.modulate = Color(0.4, 0.85, 0.45) if profit >= 0.0 else Color(0.95, 0.45, 0.4)

	_sales_label.text = str(live.daily_sales)
	_missed_label.text = str(live.daily_missed_sales)
	_reputation_label.text = "%.0f" % live.player_reputation
	_reputation_mult_label.text = LocaleService.trf("label.reputation.demand_mult_value", {
		"mult": live.player_reputation_demand_mult,
	})

	_storage_list.clear()
	var storage_keys: Array = live.storage.keys()
	storage_keys.sort()
	for raw_good_id in storage_keys:
		var good_id := str(raw_good_id)
		var qty: int = int(live.storage.get(good_id, 0))
		if qty <= 0:
			continue
		_storage_list.add_item(LocaleService.trf("label.finance_debug.storage_row", {
			"good": DataRegistry.get_good_name(good_id),
			"qty": qty,
		}))

	_prices_list.clear()
	var price_keys: Array = live.price_levels.keys()
	price_keys.sort()
	for raw_good_id in price_keys:
		var good_id := str(raw_good_id)
		var level: int = int(live.price_levels.get(good_id, 0))
		var price: float = float(live.prices.get(good_id, 0.0))
		_prices_list.add_item(LocaleService.trf("label.finance_debug.price_row", {
			"good": DataRegistry.get_good_name(good_id),
			"level": level,
			"price": int(round(price)),
		}))


func _render_history(records: Array[DayFinanceRecord]) -> void:
	_history_list.clear()
	_history_list.add_item(LocaleService.trf("label.finance_debug.history_header"))

	for record in records:
		var profit_sign := "+" if record.profit >= 0.0 else ""
		_history_list.add_item(
			"D%d\t%.0f\t%.0f\t%s%.0f\t%d\t%d\t%.0f" % [
				record.day,
				record.revenue,
				record.expenses,
				profit_sign,
				record.profit,
				record.sales_count,
				record.missed_sales,
				record.cash_end_of_day,
			]
		)
