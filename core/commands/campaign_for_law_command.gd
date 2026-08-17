class_name CampaignForLawCommand
extends RefCounted
## Агитация за закон: игрок тратит cash, NPC с хорошим отношением сдвигают голос.


const DEFAULT_COST := 50.0


static func execute(business_id: String, amount: float = DEFAULT_COST) -> CommandResult:
	var business := GameState.get_business(business_id)
	var validation := _validate(business, amount)
	if not validation.success:
		return validation

	var formula := GameState.get_voting_formula()
	if formula == null:
		return CommandResult.fail("Формула голосования не найдена")

	business.cash -= amount
	EventBus.business_cash_changed.emit(business_id, business.cash)

	var affected := 0
	for npc in GameState.get_npcs_sorted():
		if npc.relationship_to_player < formula.relationship_self_interest_min:
			continue
		var next_bonus := npc.campaign_vote_bonus + formula.campaign_bonus_per_shift
		npc.campaign_vote_bonus = minf(next_bonus, formula.max_campaign_bonus)
		affected += 1

	EventBus.law_campaign_applied.emit(business_id, amount, affected)
	EventBus.state_changed.emit()
	return CommandResult.ok()


static func _validate(business: BusinessState, amount: float) -> CommandResult:
	if business == null:
		return CommandResult.fail("Предприятие не найдено")
	if amount <= 0.0:
		return CommandResult.fail("Сумма агитации должна быть больше нуля")
	if business.cash < amount:
		return CommandResult.fail("Недостаточно средств для агитации")
	return CommandResult.ok()
