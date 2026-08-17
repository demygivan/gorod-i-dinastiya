class_name NpcPurchaseEvent
extends RefCounted
## Результат попытки покупки одного NPC за тик спроса.


enum Outcome {
	SKIPPED,
	TOO_EXPENSIVE,
	NO_CASH,
	NO_STOCK,
	PURCHASED,
}

var npc_id: String = ""
var good_id: String = ""
var intended_qty: int = 0
var sold_qty: int = 0
var revenue: float = 0.0
var outcome: Outcome = Outcome.SKIPPED
var npc_cash_after: float = 0.0


static func skipped(npc_id: String) -> NpcPurchaseEvent:
	var event := NpcPurchaseEvent.new()
	event.npc_id = npc_id
	event.outcome = Outcome.SKIPPED
	return event
