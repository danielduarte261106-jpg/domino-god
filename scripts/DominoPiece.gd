class_name DominoPiece
extends Button

signal drag_started(piece_id: int)
signal drag_dropped(piece_id: int, world_position: Vector2)

const FRUIT_COLORS: Array[Color] = [
	Color("#f8d7da"),
	Color("#fff0c2"),
	Color("#f4c2c2"),
	Color("#e5d4f2"),
	Color("#ffe0b2"),
	Color("#d8edc4"),
	Color("#ffc9de")
]
const FRUIT_NAMES: Array[String] = ["Manzana", "Banana", "Cereza", "Fresa", "Naranja", "Pera", "Uva"]

var first_fruit: int = 0
var second_fruit: int = 0
var fruit_names: Array[String] = FRUIT_NAMES
var fruit_textures: Array[Texture2D] = []
var piece_id: int = -1
var is_selected: bool = false
var is_draggable: bool = true
var is_vertical: bool = false
var _is_dragging := false
var _drag_moved := false
var _drag_origin: Vector2
var _camera: Camera2D
var _drag_tween: Tween
var _pointer_touch_index := -1
var _press_screen_position := Vector2.ZERO


func _ready() -> void:
	if not is_vertical:
		custom_minimum_size = Vector2(152, 76)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	flat = true
	toggle_mode = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if fruit_textures.is_empty():
		fruit_textures = load_fruit_textures()
	queue_redraw()


func set_vertical(vertical: bool, piece_width: float = 80.0) -> void:
	is_vertical = vertical
	if is_vertical:
		custom_minimum_size = Vector2(piece_width, piece_width * 2.0)
	else:
		custom_minimum_size = Vector2(152.0, 76.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func set_tile(first: int, second: int, names: Array[String], textures: Array[Texture2D], id: int = -1) -> void:
	first_fruit = first
	second_fruit = second
	fruit_names = names
	fruit_textures = textures
	piece_id = id
	queue_redraw()


func set_interaction(camera: Camera2D, draggable: bool) -> void:
	_camera = camera
	is_draggable = draggable


func animate_deal(delay: float = 0.0) -> void:
	modulate.a = 0.0
	scale = Vector2(0.2, 0.2)
	rotation = randf_range(-0.18, 0.18)
	var origin_y := position.y
	position.y = origin_y - 180.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.18).set_delay(delay)
	tween.tween_property(self, "position:y", origin_y, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", 0.0, 0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_selected(selected: bool) -> void:
	is_selected = selected
	set_pressed_no_signal(selected)
	if is_vertical and not _is_dragging:
		var target_scale := Vector2(1.06, 1.06) if selected else Vector2.ONE
		var tween := create_tween()
		tween.tween_property(self, "scale", target_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_draggable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
			accept_event()
		elif _is_dragging:
			_end_drag(event.position, false)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and _pointer_touch_index == -1:
			_pointer_touch_index = event.index
			_begin_drag(event.position)
			accept_event()
		elif not event.pressed and event.index == _pointer_touch_index:
			_pointer_touch_index = -1
			_end_drag(event.position, true)
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		_move_with_pointer(event.position)
		accept_event()
	elif event is InputEventScreenDrag and _is_dragging and event.index == _pointer_touch_index:
		_move_with_pointer(event.position)
		accept_event()


func _begin_drag(screen_position: Vector2) -> void:
	if _is_dragging:
		return
	_is_dragging = true
	_drag_moved = false
	_drag_origin = global_position
	_press_screen_position = screen_position
	z_index = 50
	pivot_offset = size * 0.5
	if _drag_tween != null and _drag_tween.is_running():
		_drag_tween.kill()
	_drag_tween = create_tween()
	_drag_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drag_started.emit(piece_id)
	queue_redraw()


func _move_with_pointer(screen_position: Vector2) -> void:
	var pointer_delta := screen_position - _press_screen_position
	if not _drag_moved and pointer_delta.length() > 12.0:
		_drag_moved = true
		top_level = true
		global_position = _drag_origin
	if _drag_moved:
		global_position = _drag_origin + pointer_delta


func _end_drag(screen_position: Vector2, is_touch: bool) -> void:
	if not _is_dragging:
		return
	_is_dragging = false
	if _drag_moved:
		var drop_world_position := get_global_mouse_position()
		if _camera != null and is_touch:
			drop_world_position = get_viewport().get_canvas_transform().affine_inverse() * screen_position
		elif _camera != null:
			drop_world_position = _camera.get_global_mouse_position()
		drag_dropped.emit(piece_id, drop_world_position)
	z_index = 0
	top_level = false
	if _drag_tween != null and _drag_tween.is_running():
		_drag_tween.kill()
	_drag_tween = create_tween()
	_drag_tween.set_parallel(true)
	_drag_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(get_parent()) and get_parent() is Container:
		_drag_tween.tween_property(self, "global_position", _drag_origin, 0.2).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func _draw() -> void:
	var first_color := FRUIT_COLORS[clampi(first_fruit, 0, FRUIT_COLORS.size() - 1)]
	var second_color := FRUIT_COLORS[clampi(second_fruit, 0, FRUIT_COLORS.size() - 1)]
	draw_rect(Rect2(Vector2(2, 4), size), Color(0, 0, 0, 0.25), true, 8.0)

	if is_vertical:
		var middle := size.y * 0.5
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, middle)), first_color)
		draw_rect(Rect2(Vector2(0.0, middle), Vector2(size.x, size.y - middle)), second_color)
		_draw_fruit(first_fruit, Rect2(Vector2(4.0, 4.0), Vector2(size.x - 8.0, middle - 8.0)))
		_draw_fruit(second_fruit, Rect2(Vector2(4.0, middle + 4.0), Vector2(size.x - 8.0, size.y - middle - 8.0)))
		draw_line(Vector2(2.0, middle), Vector2(size.x - 2.0, middle), Color("#57635a"), 2.0)
	else:
		var middle := size.x * 0.5
		draw_rect(Rect2(Vector2.ZERO, Vector2(middle, size.y)), first_color)
		draw_rect(Rect2(Vector2(middle, 0.0), Vector2(size.x - middle, size.y)), second_color)
		_draw_fruit(first_fruit, Rect2(Vector2(3.0, 3.0), Vector2(middle - 6.0, size.y - 6.0)))
		_draw_fruit(second_fruit, Rect2(Vector2(middle + 3.0, 3.0), Vector2(middle - 6.0, size.y - 6.0)))
		draw_line(Vector2(middle, 2.0), Vector2(middle, size.y - 2.0), Color("#57635a"), 2.0)

	if _is_dragging or is_selected:
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0.1, 0.85, 0.58, 0.28), true, 8.0)
	var border_color := Color("#16a879") if _is_dragging or is_selected else Color("#45524b")
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 3.5 if _is_dragging or is_selected else 2.0)


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


static func load_fruit_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	textures.resize(FRUIT_NAMES.size())
	var desktop_dir := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("frutas")
	var desktop_files := _image_files(desktop_dir)
	if not desktop_files.is_empty():
		_load_texture_files(desktop_files, true, textures)
	else:
		_load_texture_files(_image_files("res://assets/frutas"), false, textures)
	return textures


static func _image_files(directory_path: String) -> Array[String]:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return []
	var files: Array[String] = []
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			files.append(directory_path.path_join(file_name))
	files.sort()
	return files


static func _load_texture_files(files: Array[String], from_filesystem: bool, textures: Array[Texture2D]) -> void:
	var next_fallback_index := 0
	for file_path in files:
		var stem := file_path.get_file().get_basename().to_lower()
		var fruit_index := -1
		for index in range(FRUIT_NAMES.size()):
			if stem.contains(FRUIT_NAMES[index].to_lower()):
				fruit_index = index
				break
		if fruit_index < 0:
			while next_fallback_index < textures.size() and textures[next_fallback_index] != null:
				next_fallback_index += 1
			fruit_index = next_fallback_index
		if fruit_index >= textures.size() or textures[fruit_index] != null:
			continue
		if from_filesystem:
			var image := Image.new()
			var error := image.load(file_path)
			if error != OK:
				push_warning("No se pudo cargar la textura de fruta: %s" % file_path)
				continue
			textures[fruit_index] = ImageTexture.create_from_image(image)
		else:
			var texture := ResourceLoader.load(file_path) as Texture2D
			if texture == null:
				push_warning("El recurso no es una textura válida: %s" % file_path)
				continue
			textures[fruit_index] = texture
