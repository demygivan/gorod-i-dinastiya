@tool
class_name PlacedBuildingView
extends StaticBody2D
## Визуальное здание на слоте карты.


## Keep in sync with tools/generate_coastal_layout.py FOOTPRINT / TOWN_HALL_FOOTPRINT.
const FOOTPRINT_TILES := 2
const TOWN_HALL_FOOTPRINT_TILES := 3
## Small inset so the face sits near the road, not in the plot center.
const SLOT_GAP_RATIO := 1.0 / 8.0
const COLOR_BY_KIND := {
	"town_hall": Color(0.62, 0.64, 0.72),
	"house": Color(0.72, 0.58, 0.38),
	"hut": Color(0.66, 0.52, 0.34),
	"mansion": Color(0.78, 0.62, 0.48),
	"workshop": Color(0.52, 0.46, 0.42),
	"bakery": Color(0.9, 0.78, 0.45),
	"tavern": Color(0.85, 0.55, 0.2),
	"cemetery": Color(0.38, 0.42, 0.34),
	"church": Color(0.82, 0.82, 0.78),
	"watchtower": Color(0.55, 0.52, 0.48),
}
const COLOR_BY_GROUP := {
	"Patron": Color(0.88, 0.7, 0.38),
	"Craftsman": Color(0.62, 0.5, 0.4),
	"Scholar": Color(0.7, 0.74, 0.82),
	"Rogue": Color(0.52, 0.32, 0.36),
	"Infrastructure": Color(0.7, 0.58, 0.42),
}

var visual_kind: String = ""
var visual_group: String = ""
var label_text: String = ""


func setup_from_assignment(assignment: CityLayoutAssigner.Assignment) -> void:
	visual_kind = assignment.visual_kind
	visual_group = assignment.group
	label_text = _resolve_label(assignment.name_key, assignment.entry_id)
	collision_layer = 1
	collision_mask = 0
	_ensure_footprint_collision()
	queue_redraw()


func setup_placeholder(kind: String, label: String = "") -> void:
	visual_kind = kind
	visual_group = ""
	label_text = label
	collision_layer = 1
	collision_mask = 0
	_ensure_footprint_collision()
	queue_redraw()


func _ensure_footprint_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)

	var tiles := TOWN_HALL_FOOTPRINT_TILES if visual_kind == "town_hall" else FOOTPRINT_TILES
	var tile := float(CityPlaceholderTileset.TILE_SIZE)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles * tile, tiles * tile)
	shape_node.shape = rect


func _resolve_label(name_key: String, entry_id: String) -> String:
	if not name_key.is_empty() and not Engine.is_editor_hint():
		return LocaleService.trf(name_key)
	if not entry_id.is_empty():
		return entry_id
	return name_key


func _draw() -> void:
	if visual_kind.is_empty():
		return

	var tiles := TOWN_HALL_FOOTPRINT_TILES if visual_kind == "town_hall" else FOOTPRINT_TILES
	var tile := float(CityPlaceholderTileset.TILE_SIZE)
	var size := Vector2(tiles * tile, tiles * tile)
	var gap := size * SLOT_GAP_RATIO
	var draw_size := size - gap
	var origin := Vector2(-draw_size.x * 0.5, -draw_size.y * 0.5)
	var fill: Color = COLOR_BY_KIND.get(visual_kind, COLOR_BY_GROUP.get(visual_group, Color(0.7, 0.7, 0.7)))
	draw_rect(Rect2(origin, draw_size), fill)
	draw_rect(Rect2(origin, draw_size), Color(0.18, 0.14, 0.1), false, 2.0)

	if visual_kind == "town_hall":
		draw_rect(
			Rect2(origin + Vector2(draw_size.x * 0.35, draw_size.y * 0.15), Vector2(draw_size.x * 0.3, draw_size.y * 0.55)),
			Color(0.48, 0.5, 0.58),
		)

	if label_text.is_empty():
		return

	var font := ThemeDB.fallback_font
	var font_size := 14 if visual_kind != "town_hall" else 15
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, origin.y - 8),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0.12, 0.08, 0.05),
	)
