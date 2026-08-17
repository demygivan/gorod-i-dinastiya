extends Node2D
## Спавн NpcView и визуальная реакция на покупки. Presentation-only.


const NPC_VIEW_SCENE := preload("res://world/npc_view.tscn")

@export var debug_log: bool = false

var _views: Dictionary = {} ## npc_id -> NpcView


func _ready() -> void:
	EventBus.npcs_initialized.connect(_spawn_all_npcs)
	EventBus.npc_shopping_visit.connect(_on_npc_shopping_visit)
	EventBus.npc_purchase_recorded.connect(_on_npc_purchase_recorded)
	EventBus.game_loaded.connect(_on_game_loaded)

	if not GameState.npcs.is_empty():
		call_deferred("_spawn_all_npcs")


func get_view(npc_id: String) -> NpcView:
	return _views.get(npc_id, null)


func _on_game_loaded(_slot_name: String) -> void:
	_spawn_all_npcs()


func _spawn_all_npcs() -> void:
	for child in get_children():
		if child is NpcView:
			child.queue_free()
	_views.clear()

	for npc in GameState.get_npcs_sorted():
		var view: NpcView = NPC_VIEW_SCENE.instantiate()
		view.name = "NpcView_%s" % npc.id
		add_child(view)
		view.bind(npc.id, npc.archetype_id)
		_views[npc.id] = view

	if debug_log:
		print("[NpcViewManager] spawned %d views" % _views.size())


func _on_npc_shopping_visit(npc_id: String, _business_id: String) -> void:
	_flash_purchase(npc_id, true)


func _on_npc_purchase_recorded(
	npc_id: String,
	business_id: String,
	_good_id: String,
	outcome: int,
	_day: int,
) -> void:
	var business := GameState.get_business(business_id)
	if business != null and business.type_id == "tavern":
		_flash_purchase(npc_id, outcome == NpcPurchaseEvent.Outcome.PURCHASED)


func _flash_purchase(npc_id: String, success: bool) -> void:
	var view: NpcView = get_view(npc_id)
	if view == null:
		if debug_log:
			push_warning("[NpcViewManager] no view for %s" % npc_id)
		return
	view.show_purchase_result(success)
