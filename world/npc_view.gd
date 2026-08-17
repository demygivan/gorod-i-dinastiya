extends CharacterBody2D
class_name NpcView
## Визуальное представление NPC. Читает current_cell, не считает путь.


const PLACEHOLDER_FRAME_SIZE := Vector2(10, 14)
const SNAP_DISTANCE_TILES := 2.0

@export var walk_speed: float = 90.0
@export var visit_wait_seconds: float = 0.85

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _indicator: Label = $PurchaseIndicator

var npc_id: String = ""
var _showing_indicator := false


func _ready() -> void:
	_setup_placeholder_frames()
	_indicator.visible = false
	_play_idle()
	set_process(true)
	EventBus.simulation_paused_changed.connect(_on_simulation_paused_changed)


func bind(id: String, archetype_id: String = "") -> void:
	npc_id = id
	_apply_archetype_tint(archetype_id)
	_sync_from_state()


func show_purchase_result(success: bool) -> void:
	_show_purchase_indicator(success)
	await get_tree().create_timer(visit_wait_seconds).timeout
	_hide_purchase_indicator()


func _process(delta: float) -> void:
	if SimulationClock.paused:
		return

	var npc := GameState.get_npc(npc_id)
	if npc == null or not npc.has_cell() or npc.is_at_home():
		visible = false
		collision_layer = 0
		return
	visible = true
	collision_layer = 1

	var target_pos := _cell_to_world(npc.current_cell)
	var snap_distance := float(CityPlaceholderTileset.TILE_SIZE) * SNAP_DISTANCE_TILES
	if global_position.distance_to(target_pos) > snap_distance:
		global_position = target_pos
		_play_idle()
		return

	var speed := walk_speed * float(SimulationClock.speed_multiplier)
	var previous := global_position
	global_position = global_position.move_toward(target_pos, speed * delta)
	var moved := global_position.distance_to(previous) > 0.05
	if moved:
		_update_walk_facing(global_position.x - previous.x)
		_play_walk()
	elif not _showing_indicator:
		_play_idle()


func _sync_from_state() -> void:
	var npc := GameState.get_npc(npc_id)
	if npc == null or not npc.has_cell() or npc.is_at_home():
		visible = false
		collision_layer = 0
		return
	visible = true
	collision_layer = 1
	global_position = _cell_to_world(npc.current_cell)


func _cell_to_world(cell: Vector2i) -> Vector2:
	var map := _find_city_map()
	if map != null and map.has_method("cell_to_world"):
		return map.cell_to_world(cell)
	var tile := float(CityPlaceholderTileset.TILE_SIZE)
	return Vector2((float(cell.x) + 0.5) * tile, (float(cell.y) + 0.5) * tile)


func _find_city_map() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("cell_to_world"):
			return node
		node = node.get_parent()
	return null


func _show_purchase_indicator(success: bool) -> void:
	_showing_indicator = true
	_indicator.text = LocaleService.trf("label.npc.purchase_ok") if success else LocaleService.trf("label.npc.purchase_fail")
	_indicator.modulate = Color(0.35, 0.9, 0.45) if success else Color(0.95, 0.45, 0.4)
	_indicator.visible = true
	_play_idle()


func _hide_purchase_indicator() -> void:
	_showing_indicator = false
	_indicator.visible = false


func _play_idle() -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"default"):
		_sprite.play(&"default")
		_sprite.pause()
		_sprite.frame = 0


func _play_walk() -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"default"):
		_sprite.play(&"default")
		_sprite.frame = 1


func _update_walk_facing(direction_x: float) -> void:
	if absf(direction_x) > 0.1:
		_sprite.flip_h = direction_x < 0.0


func _setup_placeholder_frames() -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.get_frame_count(&"default") >= 2:
		return

	var frames := _sprite.sprite_frames
	if frames == null:
		frames = SpriteFrames.new()

	if not frames.has_animation(&"default"):
		frames.add_animation(&"default")
	frames.set_animation_speed(&"default", 1.0)

	while frames.get_frame_count(&"default") > 0:
		frames.remove_frame(&"default", 0)

	frames.add_frame(&"default", _make_placeholder_texture(Color(0.82, 0.68, 0.45)), 0)
	frames.add_frame(&"default", _make_placeholder_texture(Color(0.72, 0.58, 0.38)), 1)
	_sprite.sprite_frames = frames
	_sprite.play(&"default")


func _make_placeholder_texture(color: Color) -> Texture2D:
	var image := Image.create(
		int(PLACEHOLDER_FRAME_SIZE.x),
		int(PLACEHOLDER_FRAME_SIZE.y),
		false,
		Image.FORMAT_RGBA8,
	)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _apply_archetype_tint(archetype_id: String) -> void:
	match archetype_id:
		"peasant":
			modulate = Color(0.9, 0.82, 0.65)
		"craftsman":
			modulate = Color(0.75, 0.78, 0.9)
		"merchant":
			modulate = Color(0.85, 0.9, 0.55)
		"noble":
			modulate = Color(0.82, 0.72, 0.95)
		"laborer":
			modulate = Color(0.78, 0.72, 0.68)
		"elder":
			modulate = Color(0.72, 0.82, 0.78)
		_:
			modulate = Color.WHITE


func _on_simulation_paused_changed(_is_paused: bool) -> void:
	if SimulationClock.paused:
		_play_idle()
