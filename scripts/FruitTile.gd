extends Button

const FRUIT_COLORS: Array[Color] = [
	Color("#f8d7da"),
	Color("#fff0c2"),
	Color("#f4c2c2"),
	Color("#e5d4f2"),
	Color("#ffe0b2"),
	Color("#d8edc4"),
	Color("#ffc9de")
]

var first_fruit: int = 0
var second_fruit: int = 0
var fruit_names: Array[String] = []
var fruit_textures: Array[Texture2D] = []
var is_selected: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(152, 76)
	size = custom_minimum_size
	flat = true
	toggle_mode = true
	queue_redraw()


func set_tile(first: int, second: int, names: Array[String], textures: Array[Texture2D]) -> void:
	first_fruit = first
	second_fruit = second
	fruit_names = names
	fruit_textures = textures
	queue_redraw()


func set_selected(selected: bool) -> void:
	is_selected = selected
	set_pressed_no_signal(selected)
	queue_redraw()


func _draw() -> void:
	var middle := size.x * 0.5
	draw_rect(Rect2(Vector2.ZERO, Vector2(middle, size.y)), FRUIT_COLORS[first_fruit])
	draw_rect(Rect2(Vector2(middle, 0.0), Vector2(size.x - middle, size.y)), FRUIT_COLORS[second_fruit])
	_draw_fruit(first_fruit, Rect2(Vector2(3.0, 3.0), Vector2(middle - 6.0, size.y - 6.0)))
	_draw_fruit(second_fruit, Rect2(Vector2(middle + 3.0, 3.0), Vector2(middle - 6.0, size.y - 6.0)))
	draw_line(Vector2(middle, 2.0), Vector2(middle, size.y - 2.0), Color("#57635a"), 2.0)
	var border_color := Color("#177245") if is_selected else Color("#45524b")
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 4.0 if is_selected else 2.0)


func _draw_fruit(fruit_index: int, rect: Rect2) -> void:
	if fruit_index < fruit_textures.size() and fruit_textures[fruit_index] != null:
		draw_texture_rect(fruit_textures[fruit_index], rect, false)
		return
	var fruit_name := fruit_names[fruit_index] if fruit_index < fruit_names.size() else "Fruta"
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(
			font,
			rect.position + Vector2(2.0, rect.size.y * 0.5 + 5.0),
			fruit_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x - 4.0,
			14,
			Color("#27332c")
		)
