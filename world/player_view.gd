extends CharacterBody2D
class_name PlayerView
## Визуальное представление героя. Читает current_cell, не считает путь.


const PLACEHOLDER_FRAME_SIZE := Vector2(12, 16)
const SNAP_DISTANCE_TILES := 2.0

@export var walk_speed: float = 90.0
@export var character_id: String = "hero_1"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_setup_placeholder_frames()
	_play_idle()
	set_process(true)
	if character_id.is_empty():
		character_id = GameState.DEFAULT_CHARACTER_ID
	EventBus.simulation_paused_changed.connect(_on_simulation_paused_changed)
	EventBus.characters_initialized.connect(_sync_from_state)
	EventBus.game_loaded.connect(_on_game_loaded)
	_sync_from_state()


func _process(delta: float) -> void:
	if SimulationClock.paused:
		return

	var character := GameState.get_character(character_id)
	if character == null or not character.has_cell():
		visible = false
		return
	visible = true

	var target_pos := _cell_to_world(character.current_cell)
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
	else:
		_play_idle()


func _sync_from_state() -> void:
	var character := GameState.get_character(character_id)
	if character == null or not character.has_cell():
		visible = false
		return
	visible = true
	global_position = _cell_to_world(character.current_cell)


func _on_game_loaded(_slot_name: String) -> void:
	_sync_from_state()


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

	frames.add_frame(&"default", _make_placeholder_texture(Color(0.86, 0.28, 0.24)), 0)
	frames.add_frame(&"default", _make_placeholder_texture(Color(0.72, 0.18, 0.16)), 1)
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


func _on_simulation_paused_changed(_is_paused: bool) -> void:
	if SimulationClock.paused:
		_play_idle()
