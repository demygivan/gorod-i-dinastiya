extends Node
## Read-модель политики для debug UI. Слушает EventBus, не мутирует GameState.


signal politics_updated()


var proposed_law_id: String = ""
var last_vote_summary: String = ""
var last_vote_day: int = 0
var last_vote_passed: bool = false
var active_law_summaries: PackedStringArray = PackedStringArray()
var daily_cost_multiplier: float = 1.0
var next_vote_day: int = 0


func _ready() -> void:
	call_deferred("_bootstrap_from_game_state")
	_connect_event_bus()


func _connect_event_bus() -> void:
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.council_vote_completed.connect(_on_council_vote_completed)
	EventBus.law_activated.connect(_on_law_changed)
	EventBus.law_expired.connect(_on_law_changed)
	EventBus.law_campaign_applied.connect(_on_law_campaign_applied)
	SimulationClock.day_changed.connect(_on_day_changed)


func _bootstrap_from_game_state() -> void:
	rebuild_from_save()
	politics_updated.emit()


func rebuild_from_save() -> void:
	proposed_law_id = GameState.proposed_law_id
	_refresh_from_game_state()
	if GameState.last_vote_result != null:
		_apply_vote_result(GameState.last_vote_result)
	else:
		last_vote_summary = LocaleService.trf("label.common.dash")
		last_vote_day = GameState.last_vote_day
		last_vote_passed = false


func _on_game_loaded(_slot_name: String) -> void:
	rebuild_from_save()
	politics_updated.emit()


func _on_locale_changed(_locale_code: String) -> void:
	rebuild_from_save()
	politics_updated.emit()


func _on_council_vote_completed(
	law_id: String,
	passed: bool,
	votes_for: int,
	votes_against: int,
	day: int,
) -> void:
	last_vote_summary = LocaleService.trf("msg.politics.vote_debug", {
		"day": day,
		"law": law_id,
		"for": votes_for,
		"against": votes_against,
		"result": LocaleService.trf("msg.politics.passed" if passed else "msg.politics.rejected"),
	})
	last_vote_day = day
	last_vote_passed = passed
	_refresh_from_game_state()
	politics_updated.emit()


func _on_law_changed(_law_id: String, _arg = null) -> void:
	_refresh_from_game_state()
	politics_updated.emit()


func _on_law_campaign_applied(_business_id: String, _amount: float, npcs_affected: int) -> void:
	last_vote_summary = LocaleService.trf("msg.politics.campaign_applied", {"count": npcs_affected})
	politics_updated.emit()


func _on_day_changed(_day: int) -> void:
	_refresh_from_game_state()
	politics_updated.emit()


func _refresh_from_game_state() -> void:
	proposed_law_id = GameState.proposed_law_id
	daily_cost_multiplier = LawEffects.get_daily_cost_multiplier(
		GameState.laws,
		SimulationClock.day,
	)
	next_vote_day = _compute_next_vote_day()
	active_law_summaries = _build_active_law_summaries()


func _apply_vote_result(result: VoteResult) -> void:
	last_vote_summary = result.get_summary()
	last_vote_day = result.day
	last_vote_passed = result.passed


func _compute_next_vote_day() -> int:
	if GameState.proposed_law_id.is_empty():
		return 0

	var day := SimulationClock.day
	if day < GameState.council_first_vote_day:
		return GameState.council_first_vote_day

	var offset := day - GameState.council_first_vote_day
	var steps := int(floor(float(offset) / float(GameState.council_vote_interval_days))) + 1
	return GameState.council_first_vote_day + steps * GameState.council_vote_interval_days


func _build_active_law_summaries() -> PackedStringArray:
	var summaries := PackedStringArray()
	var current_day := SimulationClock.day

	for raw_law_id in GameState.laws:
		var law_state: LawState = GameState.laws[raw_law_id]
		if law_state == null or not law_state.is_active:
			continue
		if law_state.is_expired(current_day):
			continue

		var definition := DataRegistry.get_law(str(raw_law_id))
		var name := DataRegistry.get_law_name(str(raw_law_id))
		var effect_text := _format_effect(definition)
		var duration_text := _format_duration(law_state, current_day)
		summaries.append(LocaleService.trf("label.politics.active_law_line", {
			"name": name,
			"effect": effect_text,
			"duration": duration_text,
		}))

	if summaries.is_empty():
		summaries.append(LocaleService.trf("label.common.dash"))
	return summaries


func _format_effect(definition: LawDefinition) -> String:
	if definition == null:
		return LocaleService.trf("label.politics.no_effect")
	match definition.effect_type:
		LawDefinition.EFFECT_TAX_REDUCTION:
			return LocaleService.trf(
				"label.politics.effect_cost_mult",
				{"mult": 1.0 - definition.effect_value},
			)
		_:
			return definition.effect_type


func _format_duration(law_state: LawState, current_day: int) -> String:
	if law_state.expires_day < 0:
		return LocaleService.trf("label.politics.duration_permanent")
	var remaining := law_state.get_remaining_days(current_day)
	return LocaleService.trf("label.politics.duration_days_left", {"days": remaining})
