extends Camera2D
## Pan (СКМ / стрелки) и zoom (колёсико) для карты города.

const MIN_ZOOM := Vector2(0.4, 0.4)
const MAX_ZOOM := Vector2(5.0, 5.0)
const PAN_KEYS := {
	KEY_W: Vector2.UP,
	KEY_S: Vector2.DOWN,
	KEY_A: Vector2.LEFT,
	KEY_D: Vector2.RIGHT,
}
const KEYBOARD_PAN_SPEED := 520.0

var _dragging := false


func _ready() -> void:
	make_current()


func _process(delta: float) -> void:
	_apply_keyboard_pan(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(1.12, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(1.0 / 1.12, event.position)
		MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed


func _apply_keyboard_pan(delta: float) -> void:
	var direction := Vector2.ZERO
	for key in PAN_KEYS:
		if Input.is_key_pressed(key):
			direction += PAN_KEYS[key]

	if direction != Vector2.ZERO:
		position += direction.normalized() * KEYBOARD_PAN_SPEED * delta / zoom.x


func _zoom_at_point(factor: float, screen_position: Vector2) -> void:
	var old_zoom := zoom
	var new_zoom := (zoom * factor).clamp(MIN_ZOOM, MAX_ZOOM)
	if new_zoom == old_zoom:
		return

	var world_before := get_global_transform().affine_inverse() * screen_position
	zoom = new_zoom
	var world_after := get_global_transform().affine_inverse() * screen_position
	position += world_before - world_after
